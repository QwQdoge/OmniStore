from functools import wraps
import json
import sys
import argparse
import aiohttp
import logging
import asyncio
import inspect
import os
import re
import shutil
import signal
import contextlib
import contextvars
from pathlib import Path
from typing import Optional
from pydantic import BaseModel, Field, field_validator, ValidationError
from rich.console import Console
from rich.logging import RichHandler
from rich.panel import Panel
from rich.table import Table
from core.friendly_messages import get_friendly_message

# Initial rich console
console = Console(force_terminal=True)

# Murphy-proof: Context-aware output redirection for async daemon concurrency
# Prevents cross-contamination of stdout when multiple daemon clients are active.
captured_output_var = contextvars.ContextVar("captured_output", default=None)

# Force all print statements to flush immediately, ensuring real-time output to Flutter.
_orig_print = print

def print(*args, **kwargs):
    msg = " ".join(map(str, args))

    # Check if we are in a redirected context (Daemon request)
    buf = captured_output_var.get()
    if buf is not None:
        buf.write(msg + "\n")
        return

    # Protocol-prefixed messages are always allowed
    if any(msg.startswith(p) for p in ["[CALLBACK]", "[PROGRESS]", "[SPEED]"]):
        _orig_print(*args, **kwargs, flush=True)
        return

    json_mode = getattr(main, "json_mode_active", False)
    if json_mode:
        # Strict mode: in JSON mode, ONLY allow structured protocol messages or JSON strings
        stripped_msg = msg.strip()
        if (stripped_msg.startswith("{") and stripped_msg.endswith("}")) or \
           (stripped_msg.startswith("[") and stripped_msg.endswith("]")) or \
           (stripped_msg in ("true", "false", "null")):
            _orig_print(*args, **kwargs, flush=True)
        return

    _orig_print(*args, **kwargs, flush=True)

class SafeStdout:
    """Murphy-proof stdout proxy that respects task-local redirection."""
    def __init__(self, original):
        self.original = original

    def __getattr__(self, name):
        return getattr(self.original, name)

    def write(self, data):
        buf = captured_output_var.get()
        if buf is not None:
            buf.write(data)
        else:
            self.original.write(data)

    def flush(self):
        buf = captured_output_var.get()
        if buf is not None:
            if hasattr(buf, "flush"):
                buf.flush()
        else:
            self.original.flush()

# Globally hijack sys.stdout to be context-aware
sys.stdout = SafeStdout(sys.stdout) # type: ignore

# Path handling optimization
BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

# Enhanced logging config
def setup_logging(level="INFO", json_mode=False):
    log_level = getattr(logging, level.upper(), logging.INFO)
    if json_mode:
        logging.basicConfig(
            level=log_level,
            format="%(message)s",
            handlers=[logging.StreamHandler(sys.stderr)]
        )
    else:
        logging.basicConfig(
            level=log_level,
            format="%(message)s",
            datefmt="[%X]",
            handlers=[RichHandler(console=console, rich_tracebacks=True)]
        )

if hasattr(sys.stderr, 'reconfigure'):
    sys.stdout.reconfigure(  # type: ignore
        line_buffering=True,
        encoding='utf-8',
        errors='replace'
    )

from core.search.manager import SearchManager
from core.habit_tracker import HabitTracker
from core.recommendation_manager import RecommendationManager
from core.config_loader import ConfigManager
from core.cache_manager import CacheManager
from core.env_manager import EnvManager
from core.subprocess_utils import safe_subprocess

async def daemon_watchdog(stop_event: asyncio.Event):
    """
    Murphy-proof watchdog that monitors the parent process.
    If the parent process (Flutter UI) vanishes, the daemon will self-terminate.
    """
    import os
    import time
    parent_pid = os.getppid()
    if parent_pid == 1: # Already orphaned or running as init?
        return

    while not stop_event.is_set():
        try:
            # kill -0 check for parent process liveness
            os.kill(parent_pid, 0)
        except OSError:
            logging.error(f"Murphy-proof Watchdog: Parent process {parent_pid} vanished. Self-terminating...")
            stop_event.set()
            break
        await asyncio.sleep(10)

async def handle_daemon_client(backend, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    """
    Murphy-proof daemon client handler.
    Ensures per-client isolation, payload limits, and robust error recovery.
    """
    import io
    client_addr = writer.get_extra_info('peername')
    logging.debug(f"New daemon client connected: {client_addr}")

    try:
        while True:
            # 1. Read request with strict line-length limit to prevent OOM
            try:
                # Limit read size to 1MB + some buffer to avoid memory explosion
                line_bytes = await asyncio.wait_for(reader.readline(), timeout=300)
                if not line_bytes:
                    break

                if len(line_bytes) > 1024 * 1024 + 1024:
                    raise ValueError("Payload size limit exceeded")

                line = line_bytes.decode('utf-8', errors='replace').strip()
                if not line:
                    continue

                try:
                    cmd_data = DaemonRequest.model_validate_json(line)
                except ValidationError as ve:
                    logging.error(f"Daemon Validation error from {client_addr}: {ve}")
                    writer.write(json.dumps({"status": "error", "error": f"Validation Failed: {ve.errors()[0]['msg']}"}).encode('utf-8') + b'\n')
                    await writer.drain()
                    continue
                except json.JSONDecodeError as je:
                    logging.error(f"Daemon JSON error from {client_addr}: {je}")
                    writer.write(json.dumps({"status": "error", "error": "Invalid JSON format"}).encode('utf-8') + b'\n')
                    await writer.drain()
                    continue
            except asyncio.TimeoutError:
                logging.debug(f"Daemon client {client_addr} connection timed out")
                break
            except Exception as ex:
                logging.error(f"Unexpected daemon request error from {client_addr}: {ex}")
                try:
                    writer.write(json.dumps({"status": "error", "error": f"Protocol Violation: {str(ex)}"}).encode('utf-8') + b'\n')
                    await writer.drain()
                except: pass
                break
            
            # 2. Execution isolation: Use contextvars for task-local output redirection
            # This is async-safe and prevents concurrent clients from seeing each other's output.
            captured_stdout = io.StringIO()
            token = captured_output_var.set(captured_stdout)

            try:
                action = cmd_data.action
                try:
                    # Murphy-proof: Use backend context manager to ensure session liveness
                    async with backend:
                        args = cmd_data.args
                        kwargs = cmd_data.kwargs

                        # Dynamic attribute resolution
                        obj = backend
                        parts = action.split('.')
                        for part in parts:
                            obj = getattr(obj, part, None)
                            if obj is None: break

                        if obj is not None:
                            # 4. Async execution with hard 120s timeout to prevent zombie tasks
                            try:
                                if callable(obj):
                                    if inspect.iscoroutinefunction(obj):
                                        res = await asyncio.wait_for(obj(*args, **kwargs), timeout=120)
                                    else:
                                        res = obj(*args, **kwargs)
                                else:
                                    res = obj

                                stdout_content = captured_stdout.getvalue()
                                response_payload = json.dumps({
                                    "status": "success",
                                    "response": res,
                                    "stdout": stdout_content
                                }, ensure_ascii=False).encode('utf-8') + b'\n'
                                writer.write(response_payload)
                            except asyncio.TimeoutError:
                                writer.write(json.dumps({"status": "error", "error": f"Action '{action}' timed out after 120s"}).encode('utf-8') + b'\n')
                            except Exception as action_e:
                                logging.error(f"Murphy-proof Action Exception [{action}]: {action_e}")
                                writer.write(json.dumps({
                                    "status": "error",
                                    "error": str(action_e),
                                    "stdout": captured_stdout.getvalue()
                                }).encode('utf-8') + b'\n')
                        else:
                            writer.write(json.dumps({"status": "error", "error": f"Method not found: {action}"}).encode('utf-8') + b'\n')
                except Exception as e:
                    import traceback
                    err_trace = traceback.format_exc()
                    logging.error(f"Daemon Action Logic Error [{action}]: {e}\n{err_trace}")
                    try:
                        # Fault Isolation: return structured error but keep daemon alive
                        writer.write(json.dumps({
                            "status": "error",
                            "error": str(e),
                            "stdout": captured_stdout.getvalue(),
                            "traceback": err_trace if backend.config.get("logging.level") == "DEBUG" else None
                        }).encode('utf-8') + b'\n')
                    except: pass
            finally:
                captured_output_var.reset(token)

            try:
                await writer.drain()
            except ConnectionError:
                break
    except asyncio.CancelledError:
        pass
    except Exception as e:
        logging.error(f"Daemon client handler fatal error: {e}")
    finally:
        try:
            writer.close()
            await writer.wait_closed()
        except:
            pass



def safe_command(func):
    """
    Murphy-proof decorator to isolate command failures and prevent backend crashes.
    Ensures that any exception within a command is caught, logged to stderr,
    and returned as a graceful error to the UI.
    """
    @wraps(func)
    async def wrapper(self, *args, **kwargs):
        json_mode = getattr(self, "json_mode", False)
        try:
            return await func(self, *args, **kwargs)
        except asyncio.CancelledError:
            # Re-raise to allow proper async task cancellation
            raise
        except Exception as e:
            import traceback
            err_trace = traceback.format_exc()
            # Divert full traceback to stderr for diagnostics, isolated from UI stdout
            error_msg = f"Murphy-proof Error in {func.__name__}: {str(e)}"
            logging.error(f"{error_msg}\n{err_trace}")

            # Attempt to notify the frontend via callback or structured JSON
            if json_mode:
                # Ensure the error output is the only thing on the line
                # and clearly marked as an error status.
                sys.stdout.write("\n") # Break possible partial line
                sys.stdout.write(json.dumps({
                    "status": "error",
                    "error": str(e),
                    "context": func.__name__,
                    "traceback": err_trace if getattr(self, "debug", False) else None
                }, ensure_ascii=False) + "\n")
                sys.stdout.flush()
            else:
                try:
                    await self._handle_error(f"Command Error ({func.__name__})", e, json_mode)
                except:
                    # Final fallback if _handle_error itself fails
                    print(f"[ERROR] {error_msg}")
            return False
    return wrapper


class OmnistoreBackend:
    """
    Main backend controller for OmniStore.
    Coordinates between configuration, cache, searching, and execution modules.
    Ensures fail-safe execution and proper resource lifecycle management.
    """
    def __init__(self, json_mode: bool = False):
        self.config = ConfigManager()
        self.cache = CacheManager()
        self.env = EnvManager()
        # ⚡ Shared HabitTracker to avoid redundant disk I/O
        self.habit_tracker = HabitTracker()
        self.manager: Optional[SearchManager] = None
        self.recommender: Optional[RecommendationManager] = None

        self._updater = None
        self._executor = None
        self._ai = None
        self._repo_manager = None
        self._essentials = None

        self.is_action = False
        self.json_mode = json_mode
        self.session: Optional[aiohttp.ClientSession] = None

        # Murphy-proof: Reference count for shared resource management in daemon mode
        self._ref_count = 0
        self._lock = asyncio.Lock()

        setup_logging(self.config.get("logging.level", "INFO"), json_mode)

    @property
    def updater(self):
        if self._updater is None:
            from core.update_manager import UpdateManager
            self._updater = UpdateManager(self.config)
        return self._updater

    @property
    def executor(self):
        if self._executor is None:
            from core.downloader.manager import InstallExecutor
            self._executor = InstallExecutor(self)
        return self._executor

    @property
    def ai(self):
        if self._ai is None:
            from core.ai.assistant import AIAssistant
            self._ai = AIAssistant(self.config)
        return self._ai

    @property
    def repo_manager(self):
        if self._repo_manager is None:
            from core.search.custom_repo import CustomRepoManager
            self._repo_manager = CustomRepoManager(self.config, self.executor)
        return self._repo_manager

    @property
    def essentials(self):
        if self._essentials is None:
            from core.essentials import EssentialsManager
            self._essentials = EssentialsManager(self.config)
        return self._essentials

    async def initialize(self):
        """Asynchronous initialization of components requiring a network session."""
        async with self._lock:
            session_replaced = False
            if self.session is None or self.session.closed:
                # Murphy-proof: Use a customized connector with connection limits
                # to prevent file descriptor exhaustion in long-running daemon mode.
                connector = aiohttp.TCPConnector(limit=100, ttl_dns_cache=300)
                self.session = aiohttp.ClientSession(
                    connector=connector,
                    timeout=aiohttp.ClientTimeout(total=60)
                )
                session_replaced = True

            # ⚡ Bolt: Idempotent initialization prevents redundant disk I/O and object creation
            # in persistent daemon mode, saving ~100-300ms per search request.
            if self.recommender is None or session_replaced:
                self.recommender = RecommendationManager(self.session, self.habit_tracker)

            if self.manager is None or session_replaced:
                self.manager = SearchManager(
                    self.config, self.session, self.habit_tracker,
                    recommender=self.recommender, cache_manager=self.cache,
                    ai_assistant=self.ai
                )
        return self

    async def __aenter__(self):
        # ⚡ Bolt: Idempotent initialization called on every enter.
        # Ref count is incremented only AFTER successful initialization
        # to prevent stuck state on failure.
        await self.initialize()
        async with self._lock:
            self._ref_count += 1
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """
        Murphy-proof cleanup: ensures all sessions and background executors
        are explicitly destroyed only when the reference count reaches zero.
        """
        async with self._lock:
            if self._ref_count > 0:
                self._ref_count -= 1

            # ⚡ Bolt: Only perform cleanup if ref count reaches zero, allowing resource
            # persistence across multiple requests in daemon mode.
            if self._ref_count > 0:
                return

        try:
            # 1. Stop background executors first to halt new activity
            if self._executor:
                try:
                    self._executor.stop()
                except Exception as e:
                    logging.debug(f"Cleanup: Executor stop error: {e}")
                self._executor = None

            # 2. Close network sessions with timeout to prevent hanging on close
            if self.session and not self.session.closed:
                try:
                    # Murphy-proof: Aggressive timeout on session close
                    await asyncio.wait_for(self.session.close(), timeout=2.0)
                except Exception as e:
                    logging.debug(f"Cleanup: Session close error: {e}")
                self.session = None

            # 3. Close AI Assistant session if initialized
            if self._ai:
                try:
                    await self._ai.close()
                except Exception as e:
                    logging.debug(f"Cleanup: AI Assistant close error: {e}")

            # 4. Explicitly nullify large manager objects to assist GC in long-running daemon mode
            self.manager = None
            self.recommender = None
            self._ai = None
            self._updater = None
            self._repo_manager = None
            self._essentials = None

        except Exception as e:
            # Final catch-all for cleanup to ensure we don't crash the exit sequence
            logging.error(f"Murphy-proof Critical: Cleanup failure: {e}")

    # --- Unified Callback Handling ---
    async def _flutter_callback(self, msg: str, json_mode: bool = False, level: Optional[str] = None):
        """Unified log exit with level support and auto-detection"""
        if level is None:
            if msg.startswith(("[ERROR]", "[Error]")): level = "ERROR"
            elif any(msg.startswith(p) for p in ["[INFO]", "[Status]", "[Executor]"]): level = "INFO"
            elif msg.startswith("[PROGRESS]"): level = "PROGRESS"
            elif msg.startswith("[DEBUG]"): level = "DEBUG"
            else: level = "INFO"

        # Clean up legacy prefixes
        clean_msg = msg
        for prefix in ["[Status]", "[INFO]", "[ERROR]", "[Error]", "[DEBUG]", "[Executor]"]:
            if clean_msg.startswith(prefix):
                clean_msg = clean_msg.replace(prefix, "", 1).strip()
                break

        if json_mode:
            icon = {"ERROR": "❌", "SUCCESS": "✅", "INFO": "🔹", "PROGRESS": "⏳"}.get(level, "🔹")
            decorated_msg = f"{icon} {clean_msg}"

            try:
                output = json.dumps(
                    {"type": "log", "message": f"[{level.upper()}] {decorated_msg}", "level": level.upper()}, ensure_ascii=False)
                sys.stdout.write(f"[CALLBACK] {output}\n")
                sys.stdout.flush()
            except Exception as e:
                sys.stdout.write(f"[CALLBACK] {{\"type\": \"log\", \"message\": \"[ERROR] Log serialization error: {str(e)}\", \"level\": \"ERROR\"}}\n")
                sys.stdout.flush()
        else:
            if level == "ERROR":
                logging.error(clean_msg)
            elif level == "PROGRESS":
                if not clean_msg.isdigit():
                     logging.info(f"Progress: {clean_msg}%")
            else:
                logging.info(clean_msg)

    @safe_command
    async def run_search(self, query: str, json_mode: bool = False):
        async with self:
            if not self.manager:
                raise RuntimeError("SearchManager is not initialized.")

            results = await asyncio.wait_for(self.manager.search_all(query), timeout=45)
            if results is None: results = []

            if json_mode:
                self._output_json(results)
            else:
                self._output_pretty(query, results)

    @safe_command
    async def run_install(self, name: str, source: str, url: Optional[str] = None, json_mode: bool = False) -> bool:
        self.is_action = True
        package_data = {"name": name, "id": name, "source": source, "url": url}

        if self.manager and self.manager.habit_tracker:
            self.manager.habit_tracker.record_install(name, source)

        async def cb(m): await self._flutter_callback(m, json_mode)

        if not json_mode:
            console.print(Panel(f"Installing [bold green]{name}[/bold green] from [cyan]{source}[/cyan]", border_style="green"))

        success = await self.executor.install(package_data, callback=cb)
        if success:
            self.cache.invalidate_installed_cache()
            if not json_mode:
                console.print(Panel(f"Successfully installed [bold green]{name}[/bold green]! 🎉", border_style="green"))
                console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")
        return success

    @safe_command
    async def run_uninstall(self, package_name: str, source: str, json_mode: bool = False, flag: str = "-R") -> bool:
        self.is_action = True
        package_data = {"name": package_name, "id": package_name, "source": source, "flag": flag}

        async def cb(m): await self._flutter_callback(m, json_mode)

        if not json_mode:
            console.print(Panel(f"Uninstalling [bold red]{package_name}[/bold red] from [cyan]{source}[/cyan]", border_style="red"))

        success = await self.executor.uninstall(package_data, callback=cb)
        if success:
            self.cache.invalidate_installed_cache()
            if not json_mode:
                console.print(Panel(f"Successfully uninstalled [bold red]{package_name}[/bold red]! ✨", border_style="green"))
                console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")
        return success

    @safe_command
    async def run_update(self, package_name: str, source: str, json_mode: bool = False) -> bool:
        self.is_action = True
        package_data = {"name": package_name, "id": package_name, "source": source}
        async def cb(m): await self._flutter_callback(m, json_mode)

        if not json_mode:
            target = "all packages" if package_name == "all" else f"[bold green]{package_name}[/bold green]"
            console.print(Panel(f"Updating {target} via [cyan]{source}[/cyan]", border_style="blue"))

        success = await self.executor.update(package_data, callback=cb)
        if success and not json_mode:
            console.print(Panel(f"Update completed! 🎉", border_style="green"))
            console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")
        return success

    @safe_command
    async def run_check_updates(self, json_mode: bool = False):
        updates = await self.updater.check_all_updates()
        if json_mode:
            sys.stdout.write(json.dumps(updates, ensure_ascii=False) + "\n"); sys.stdout.flush()
        else:
            if not updates:
                console.print(Panel("All apps are up to date! ✨", border_style="green"))
                return

            table = Table(title="Available Updates", show_header=True, header_style="bold yellow")
            table.add_column("Source", style="cyan")
            table.add_column("Package Name", style="bold green")
            table.add_column("Current", style="red")
            table.add_column("New", style="green")

            for u in updates:
                table.add_row(u['source'], u['name'], u['current_version'], u['new_version'])

            console.print(table)
            console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")

    @safe_command
    async def run_recommendations(self, json_mode: bool = False):
        async with self:
            if not self.recommender: raise RuntimeError("RecommendationManager not initialized.")
            sources = list(self.manager.sources.values()) if self.manager else []
            results = await self.recommender.get_recommendations(sources=sources)
            if json_mode:
                sys.stdout.write(json.dumps(results, ensure_ascii=False) + "\n"); sys.stdout.flush()
            else:
                if isinstance(results, dict):
                    for category, apps in results.items():
                        print(f"\n[{category}]")
                        for app in apps:
                            if isinstance(app, dict):
                                print(f"  推荐: {app.get('name')} ({app.get('id')})")
                elif isinstance(results, list):
                    for app in results:
                        if isinstance(app, dict):
                            print(f"推荐: {app.get('name')} ({app.get('id')})")

    @safe_command
    async def run_app_details(self, app_id: str, json_mode: bool = False):
        async with self:
            if not self.recommender or not self.manager:
                raise RuntimeError("Managers are not initialized.")

            details = await asyncio.wait_for(
                self.recommender.get_details(app_id) if "." in app_id else self.recommender.find_metadata(app_id),
                timeout=30
            )
            search_name = details.get("name") or app_id.split(".")[-1]
            variants_results = await asyncio.wait_for(self.manager.search_all(search_name), timeout=30)

            norm_target = self.manager._normalize_app_name(search_name)
            matched_app = next((res for res in variants_results if self.manager._normalize_app_name(res['name']) == norm_target), None)

            if matched_app:
                details["variants"] = matched_app.get("variants", [])
                if not details.get("description") or len(details.get("description")) < 10:
                    details["description"] = matched_app.get("description", "")

            # Fetch extra info for Native/AUR variants
            # ⚡ Optimization: Parallelize extra info fetching for variants
            # Murphy-proof: Use safe_subprocess to prevent zombies
            async def _fetch_variant_info(variant):
                source = variant['source']
                if source in ("Native", "Pacman", "AUR"):
                    try:
                        binary = "pacman" if source in ("Native", "Pacman") else "yay"
                        if not shutil.which(binary):
                            return

                        flag = "-Si" if source in ("Native", "Pacman") else "-Sii"
                        cmd = [binary, flag, variant.get('name', search_name)]
                        async with safe_subprocess(*cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL, env={**os.environ, "LC_ALL": "C"}) as proc:
                            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5)
                            if stdout:
                                info = stdout.decode()
                                if (m := re.search(r"(?:Depends On|Depends)\s+:\s+(.*)", info)): variant["depends"] = m.group(1).split()
                                if (m := re.search(r"Download Size\s+:\s+(.*)", info)): variant["download_size"] = m.group(1).strip()
                                if (m := re.search(r"Installed Size\s+:\s+(.*)", info)): variant["installed_size"] = m.group(1).strip()
                    except Exception:
                        pass

            variant_tasks = [_fetch_variant_info(v) for v in details.get("variants", [])]
            if variant_tasks:
                await asyncio.wait_for(asyncio.gather(*variant_tasks), timeout=20)

            sys.stdout.write(json.dumps(details, ensure_ascii=False) + "\n"); sys.stdout.flush()

    @safe_command
    async def run_list_installed(self, json_mode: bool = False, force_refresh: bool = False):
        if not force_refresh:
            cached = self.cache.get_installed_packages() if self.cache else None
            if cached:
                if json_mode: sys.stdout.write(json.dumps(cached) + "\n"); sys.stdout.flush()
                else: self._output_installed_pretty(cached)
                return

        installed_list = []
        async with self:
            # ⚡ Optimization: Parallelize package scanning for different sources
            async def scan_appimage():
                res = []
                try:
                    apps_dir = Path.home() / "Applications"
                    if apps_dir.exists():
                        # Boundary defense: offload blocking glob to thread
                        loop = asyncio.get_running_loop()
                        files = await loop.run_in_executor(None, lambda: list(apps_dir.glob("*.AppImage")))
                        for f in files:
                            res.append({
                                "name": f.stem, "primary_source": "AppImage", "variants": [{"source": "AppImage"}],
                                "installed": True, "description": f"Local AppImage at {f}", "version": "Local", "url": f.as_uri()
                            })
                except Exception as e:
                    logging.debug(f"scan_appimage error: {e}")
                return res

            async def scan_flatpak():
                res = []
                if shutil.which("flatpak") is None:
                    return res
                try:
                    async with safe_subprocess("flatpak", "list", "--app", "--columns=name,application,version,description",
                                             stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
                        if stdout:
                            for line in stdout.decode().strip().splitlines():
                                parts = [p.strip() for p in line.split('\t')]
                                if len(parts) >= 2:
                                    res.append({
                                        "name": parts[0], "id": parts[1], "primary_source": "Flatpak", "variants": [{"source": "Flatpak"}],
                                        "installed": True, "version": parts[2] if len(parts) > 2 else "Unknown",
                                        "description": parts[3] if len(parts) > 3 else f"Flatpak app {parts[1]}"
                                    })
                except Exception:
                    pass
                return res

            async def scan_native():
                res = []
                if shutil.which("pacman") is None:
                    return res
                try:
                    async with safe_subprocess("pacman", "-Qqne", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
                        if stdout:
                            for line in stdout.decode().strip().splitlines():
                                if line: res.append({"name": line, "primary_source": "Native", "variants": [{"source": "Native"}],
                                                       "installed": True, "description": "Native package", "version": "Local"})
                except Exception:
                    pass
                return res

            async def scan_aur():
                res = []
                if shutil.which("pacman") is None:
                    return res
                try:
                    async with safe_subprocess("pacman", "-Qmq", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
                        if stdout:
                            for line in stdout.decode().strip().splitlines():
                                if line: res.append({"name": line, "primary_source": "AUR", "variants": [{"source": "AUR"}],
                                                       "installed": True, "description": "AUR package", "version": "Local"})
                except Exception:
                    pass
                return res

            results = await asyncio.gather(scan_appimage(), scan_flatpak(), scan_native(), scan_aur())
            for r in results:
                installed_list.extend(r)

            if self.recommender:
                enrich_targets = [app for app in installed_list if not app.get('icon')]
                async def _enrich_app(app):
                    try:
                        # ⚡ Optimization: Tiered enrichment logic (handled in loop below)
                        metadata = await self.recommender.find_metadata(app['name'], use_network=app.get('_use_network', True))
                        if metadata:
                            if metadata.get('icon'): app['icon'] = metadata['icon']
                            if metadata.get('description'): app['description'] = metadata['description']
                    except: pass

                if enrich_targets:
                    # ⚡ Optimization: Implement tiered enrichment for installed list
                    # Only allow network requests for the first 10 targets to balance UX and speed
                    for i, app in enumerate(enrich_targets):
                        app['_use_network'] = (i < 10)
                    await asyncio.gather(*[_enrich_app(app) for app in enrich_targets[:10]], return_exceptions=True)
                    for app in enrich_targets: app.pop('_use_network', None)

            if json_mode: sys.stdout.write(json.dumps(installed_list) + "\n"); sys.stdout.flush()
            else: self._output_installed_pretty(installed_list)
            if self.cache:
                self.cache.save_installed_packages(installed_list)

    @safe_command
    async def run_list_custom_repos(self):
        flatpaks = await self.repo_manager.list_flatpak_remotes()
        pacmans = await self.repo_manager.list_pacman_repos()
        appimages = self.repo_manager.list_appimage_feeds()
        result = {
            "flatpak": flatpaks, "pacman": pacmans,
            "appimage": [{"name": Path(url).stem, "url": url} for url in appimages],
            "config_flatpak": self.config.get("custom_repos.flatpak", []),
            "config_pacman": self.config.get("custom_repos.pacman", [])
        }
        sys.stdout.write(json.dumps(result, ensure_ascii=False) + "\n"); sys.stdout.flush()

    @safe_command
    async def run_add_custom_repo(self, repo_type: str, name: str, url: str, json_mode: bool = False) -> bool:
        self.is_action = True
        async def cb(m): await self._flutter_callback(m, json_mode)
        success = False
        if repo_type == "flatpak": success = await self.repo_manager.add_flatpak_remote(name, url, callback=cb)
        elif repo_type == "pacman": success = await self.repo_manager.add_pacman_repo(name, url, callback=cb)
        elif repo_type == "appimage":
            success = self.repo_manager.add_appimage_feed(url)
            await cb(f"[{'INFO' if success else 'ERROR'}] Added AppImage feed: {url}")
        else: await cb(f"[ERROR] Invalid repo type: {repo_type}")
        if json_mode: sys.stdout.write(json.dumps({"status": "success" if success else "error"}) + "\n"); sys.stdout.flush()
        return success

    @safe_command
    async def run_remove_custom_repo(self, repo_type: str, name: str, json_mode: bool = False) -> bool:
        self.is_action = True
        async def cb(m): await self._flutter_callback(m, json_mode)
        success = False
        if repo_type == "flatpak": success = await self.repo_manager.remove_flatpak_remote(name, callback=cb)
        elif repo_type == "pacman": success = await self.repo_manager.remove_pacman_repo(name, callback=cb)
        elif repo_type == "appimage":
            success = self.repo_manager.remove_appimage_feed(name)
            await cb(f"[{'INFO' if success else 'ERROR'}] Removed AppImage feed: {name}")
        else: await cb(f"[ERROR] Invalid repo type: {repo_type}")
        if json_mode: sys.stdout.write(json.dumps({"status": "success" if success else "error"}) + "\n"); sys.stdout.flush()
        return success

    @safe_command
    async def run_ai_explain(self, app_name: str, app_description: str = ""):
        res = await self.ai.explain_app(app_name, app_description)
        sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()

    @safe_command
    async def run_ai_recommend(self, prompt: str):
        async with self:
            if not self.manager: raise RuntimeError("SearchManager not initialized.")
            keywords = prompt.split()
            candidates = await self.manager.search_all(keywords[0] if keywords else prompt)
            res = await self.ai.recommend_apps(prompt, candidates)
            sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()

    @safe_command
    async def run_ai_analyze_error(self, error_log: str):
        res = await self.ai.analyze_error(error_log)
        sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()

    @safe_command
    async def run_ai_changelog(self, name: str, current: str, next_v: str):
        res = await self.ai.summarize_changelog(name, current, next_v)
        sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()

    @safe_command
    async def run_ai_cli(self, name: str, summary: str):
        res = await self.ai.generate_cli_command(name, summary)
        sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()

    @safe_command
    async def run_ai_conflicts(self, name: str):
        if shutil.which("pacman"):
            try:
                async with safe_subprocess("pacman", "-Qq", stdout=asyncio.subprocess.PIPE) as proc:
                    stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5)
                    res = await self.ai.detect_conflicts(name, stdout.decode().splitlines())
                    sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n")
            except: sys.stdout.write(json.dumps({"response": "Conflict check failed."}) + "\n")
        else:
            sys.stdout.write(json.dumps({"response": "pacman not found, conflict check skipped."}) + "\n")
        sys.stdout.flush()

    @safe_command
    async def run_ai_correct(self, query: str):
        res = await self.ai.suggest_correction(query)
        sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n")
        sys.stdout.flush()

    @safe_command
    async def run_ai_compare(self, name: str):
        async with self:
            if self.manager:
                candidates = await self.manager.search_all(name)
                target = next((c for c in candidates if c['name'].lower() == name.lower()), candidates[0] if candidates else None)
                if target:
                    res = await self.ai.compare_variants(name, target.get('variants', []))
                    sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n")
                else: sys.stdout.write(json.dumps({"response": "App not found for comparison."}) + "\n")
            else:
                sys.stdout.write(json.dumps({"response": "Search manager not initialized."}) + "\n")
        sys.stdout.flush()

    @safe_command
    async def run_ai_health(self):
        sys.stdout.flush() # Ensure clear buffer
        status = await self.env.check_env()
        status["orphaned_count"] = 0
        if shutil.which("pacman"):
            try:
                async with safe_subprocess("pacman", "-Qtdq", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                    stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5)
                    status["orphaned_count"] = len(stdout.decode().splitlines())
            except: pass
        res = await self.ai.generate_health_report(status)
        sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()

    @safe_command
    async def run_get_essentials(self):
        res = self.essentials.get_essentials()
        sys.stdout.write(json.dumps(res, ensure_ascii=False) + "\n"); sys.stdout.flush()

    @safe_command
    async def run_import_packages(self, filepath: str):
        res = self.essentials.import_from_file(filepath)
        sys.stdout.write(json.dumps(res, ensure_ascii=False) + "\n"); sys.stdout.flush()

    @safe_command
    async def run_export_packages(self, filepath: str):
        installed = []
        commands = [
            (["pacman", "-Qqne"], "Native"),
            (["flatpak", "list", "--app", "--columns=application"], "Flatpak"),
            (["yay", "-Qm"], "AUR")
        ]
        for cmd, src in commands:
            if not shutil.which(cmd[0]):
                continue
            try:
                async with safe_subprocess(*cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                    stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
                    if stdout:
                        for line in stdout.decode().strip().splitlines():
                            if line: installed.append({"name": line.split()[0], "source": src})
            except Exception as e:
                logging.debug(f"Export {src} failed: {e}")

        export_dir = os.path.dirname(os.path.abspath(filepath))
        if export_dir: os.makedirs(export_dir, exist_ok=True)
        with open(filepath, 'w', encoding='utf-8') as f: json.dump(installed, f, ensure_ascii=False, indent=2)

        if self.json_mode: sys.stdout.write(json.dumps({"status": "success", "count": len(installed)}) + "\n")
        else: console.print(Panel(f"Successfully exported {len(installed)} packages to {filepath}", border_style="green"))
        sys.stdout.flush()

    @safe_command
    async def run_launch(self, name: str, source: str, json_mode: bool = False) -> bool:
        async with self:
            src = source.lower()
            if src == "native":
                src = "pacman"
            if self.manager and src in self.manager.sources:
                success = await self.manager.sources[src].launch({"name": name, "id": name})
                if json_mode:
                    sys.stdout.write(json.dumps({"status": "success" if success else "error"}) + "\n")
                return success
            return False

    @safe_command
    async def run_locate(self, name: str, source: str, json_mode: bool = False) -> bool:
        async with self:
            src = source.lower()
            if src == "native":
                src = "pacman"
            if self.manager and src in self.manager.sources:
                success = await self.manager.sources[src].locate({"name": name, "id": name})
                if json_mode:
                    sys.stdout.write(json.dumps({"status": "success" if success else "error"}) + "\n")
                return success
            return False

    @safe_command
    async def run_get_storage_info(self, json_mode: bool = False):
        async with self:
            home_path = os.path.expanduser("~")
            total, used, free = shutil.disk_usage(home_path)
            
            pacman_cache = 0
            if os.path.exists("/var/cache/pacman/pkg"):
                try:
                    for entry in os.scandir("/var/cache/pacman/pkg"):
                        if entry.is_file():
                            pacman_cache += entry.stat().st_size
                except Exception:
                    pass
            
            flatpak_cache = 0
            flatpak_paths = [
                os.path.expanduser("~/.local/share/flatpak"),
                os.path.expanduser("~/.var/app")
            ]
            for p in flatpak_paths:
                if os.path.exists(p):
                    try:
                        for root, dirs, files in os.walk(p):
                            for file in files:
                                flatpak_cache += os.path.getsize(os.path.join(root, file))
                    except Exception:
                        pass
            
            omnistore_cache = 0
            omnistore_paths = [
                os.path.expanduser("~/.config/omnistore"),
                os.path.expanduser("~/.cache/omnistore")
            ]
            for p in omnistore_paths:
                if os.path.exists(p):
                    try:
                        for root, dirs, files in os.walk(p):
                            for file in files:
                                omnistore_cache += os.path.getsize(os.path.join(root, file))
                    except Exception:
                        pass
                        
            info = {
                "disk_total": total,
                "disk_used": used,
                "disk_free": free,
                "pacman_cache": pacman_cache,
                "flatpak_cache": flatpak_cache,
                "omnistore_cache": omnistore_cache,
                "total_cache": pacman_cache + flatpak_cache + omnistore_cache
            }
            
            if json_mode:
                sys.stdout.write(json.dumps(info) + "\n")
            else:
                console.print(f"Disk Total: {total / (1024**3):.2f} GB")
                console.print(f"Disk Free: {free / (1024**3):.2f} GB")
                console.print(f"Total Cache: {(pacman_cache + flatpak_cache + omnistore_cache) / (1024**2):.2f} MB")
            sys.stdout.flush()
            return info

    @safe_command
    async def run_clean_system(self, json_mode: bool = False) -> bool:
        async def cb(m): await self._flutter_callback(m, json_mode)
        try:
            if not json_mode: console.print(Panel("Starting System Cleanup", border_style="blue"))
            if shutil.which("pacman") is None:
                await cb("[INFO] pacman not found, skipping."); return True

            await cb("[INFO] Detecting orphan packages...")
            try:
                async with safe_subprocess("pacman", "-Qtdq", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE) as proc:
                    stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
                    orphans = [o.strip() for o in stdout.decode().strip().splitlines() if o.strip()]
            except Exception:
                orphans = []

            if orphans:
                await cb(f"[INFO] Cleaning {len(orphans)} orphans...");
                if not await self.executor._ensure_privileged(cb): return False
                async with safe_subprocess("sudo", "pacman", "-Rs", "--noconfirm", *orphans) as p:
                    try:
                        await asyncio.wait_for(p.wait(), timeout=60)
                    except asyncio.TimeoutError:
                        pass

            await cb("[INFO] Cleaning package cache...")
            if await self.executor._ensure_privileged(cb):
                # We do not use --noconfirm here because it defaults to 'N' for pacman -Scc.
                # Instead, we pipe 'y' to stdin so it actually clears the cache.
                async with safe_subprocess(
                    "sudo", "pacman", "-Scc",
                    stdin=asyncio.subprocess.PIPE,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.STDOUT
                ) as p:
                    try:
                        # Feed 'y' for the two prompts: 
                        # 1. remove all files from cache?
                        # 2. remove unused repositories?
                        p.stdin.write(b"y\ny\n")
                        await p.stdin.drain()
                        p.stdin.close()
                        
                        while True:
                            line_bytes = await p.stdout.readline()
                            if not line_bytes:
                                break
                            line = line_bytes.decode('utf-8', errors='ignore').strip()
                            if line:
                                await cb(f"[INFO] {line}")
                        await asyncio.wait_for(p.wait(), timeout=60)
                    except asyncio.TimeoutError:
                        if p and p.returncode is None:
                            try: p.kill()
                            except: pass

            await cb("[INFO] System cleanup finished!")
            if json_mode: sys.stdout.write(json.dumps({"status": "success"}) + "\n"); sys.stdout.flush()
            return True
        except Exception as e:
            await self._handle_error("Cleanup failed", e, json_mode)
            return False

    @safe_command
    async def run_ai_summary(self, json_mode: bool = False):
        res = await self.ai.summarize_project()
        if json_mode: sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()
        else: print(f"AI Summary:\n{res}")

    async def run_ai_health_report(self):
        """Murphy-proof: Isolated AI health report logic."""
        status = await self.env.check_env()
        status["orphaned_count"] = 0
        if shutil.which("pacman"):
            try:
                async with safe_subprocess("pacman", "-Qtdq", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                    stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5)
                    status["orphaned_count"] = len(stdout.decode().splitlines())
            except: pass
        res = await self.ai.generate_health_report(status)
        sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n")

    @safe_command
    async def run_save_config(self, config_data: dict):
        success = self.config.save(config_data)
        return success

    @safe_command
    async def run_update_env(self, env_vars: dict, json_mode: bool = False):
        import os
        for k, v in env_vars.items():
            if v is not None:
                os.environ[k] = str(v)
            elif k in os.environ:
                del os.environ[k]
        self.config.current_config = self.config.load()
        if json_mode: sys.stdout.write(json.dumps({"status": "success"}, ensure_ascii=False) + "\n"); sys.stdout.flush()
        return True

    async def shutdown(self):
        """Coordinated shutdown of the backend daemon."""
        logging.info("Coordinated shutdown requested via IPC.")
        # Trigger the main stop event if we are in daemon mode
        # This will be handled in the main() dispatch loop
        if hasattr(main, "stop_event"):
            main.stop_event.set()
        return True

    @safe_command
    async def run_ai_test(self, json_mode: bool = False):
        self.config.current_config = self.config.load()
        res = await self.ai.test_connection()
        if json_mode: sys.stdout.write(json.dumps({"status": "success" if res == "success" else "error", "response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()
        else: print(f"AI Connection Test:\n{res}")

    @safe_command
    async def run_ai_pick(self, json_mode: bool = False):
        async with self:
            if not self.recommender: raise RuntimeError("RecommendationManager not initialized.")
            recs = await self.recommender.get_recommendations()
            candidates = []
            for key in ['trending', 'featured', 'for_you']: candidates.extend(recs.get(key, []))
            seen = set()
            unique_candidates = []
            for c in candidates:
                if c['name'] not in seen:
                    seen.add(c['name']); unique_candidates.append(c)
            if unique_candidates:
                filtered = [c for c in unique_candidates if c.get('name') and c.get('description')] or unique_candidates
                res = await self.ai.pick_of_the_day(filtered[:15])
                if "PICK_JSON:" not in res and filtered: res += f"\nPICK_JSON: [\"{filtered[0]['name']}\"]"
            else: res = "Today's recommendation: OmniStore itself!"
            sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()

    async def _handle_error(self, context: str, exception: Exception, json_mode: bool):
        """Standardized error handling to prevent backend crash."""
        error_msg = f"{context}: {str(exception)}"
        if json_mode:
            sys.stdout.write(json.dumps({"status": "error", "error": error_msg, "results": [], "response": f"Error: {error_msg}"}) + "\n")
        else:
            logging.error(error_msg)
        sys.stdout.flush()

    def _output_json(self, results):
        def serialize_item(item):
            return {
                "name": str(item.get("name", "Unknown")),
                "description": str(item.get("description", "")),
                "installed": bool(item.get("installed", False) or item.get("is_installed", False)),
                "primary_source": str(item.get("primary_source") or item.get("source") or "Native"),
                "url": str(item.get("url") or ""),
                "variants": item.get("variants", []),
                "version": str(item.get("last_version") or item.get("version") or "N/A"),
                "score": int(item.get("score", 0)),
                "icon": item.get("icon"),
                "is_exact_match": item.get("is_exact_match", False),
                "screenshots": item.get("screenshots", []),
            }
        output = [serialize_item(i) for i in results]
        sys.stdout.write(json.dumps(output, ensure_ascii=False) + "\n"); sys.stdout.flush()

    def _output_pretty(self, query, results):
        if not results:
            console.print(Panel(f"No results found for [bold cyan]'{query}'[/bold cyan]", border_style="yellow"))
            return
        table = Table(title=f"Search Results: {query}", show_header=True, header_style="bold magenta")
        table.add_column("#", style="dim", width=3); table.add_column("Name", style="bold green")
        table.add_column("Status", width=12); table.add_column("Sources", style="cyan")
        table.add_column("Description", style="italic")
        for i, item in enumerate(results[:15]):
            status = "[blue]Installed[/blue]" if (item.get("installed") or item.get("is_installed")) else "[dim]Not Installed[/dim]"
            table.add_row(str(i+1), item['name'], status, ", ".join([v['source'] for v in item.get('variants', [])]),
                          (item.get('description', '')[:57] + "...") if len(item.get('description', '')) > 60 else item.get('description', ''))
        console.print(table); console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")

    def _output_installed_pretty(self, installed_list):
        if not installed_list:
            console.print(Panel("No installed applications found.", border_style="yellow"))
            return
        table = Table(title="Installed Applications", show_header=True, header_style="bold blue")
        table.add_column("Source", style="cyan"); table.add_column("Name", style="bold green")
        table.add_column("Version", style="dim"); table.add_column("Description", style="italic")
        for app in installed_list:
            table.add_row(app['primary_source'], app['name'], app.get('version', 'N/A'),
                          (app.get('description', '')[:50] + "...") if len(app.get('description', '')) > 50 else app.get('description', ''))
        console.print(table); console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")


class DaemonRequest(BaseModel):
    action: str = Field(..., min_length=1, max_length=100)
    args: list = Field(default_factory=list)
    kwargs: dict = Field(default_factory=dict)

    @field_validator("action")
    @classmethod
    def validate_action(cls, v):
        ALLOWED_ACTIONS = {
            "run_search", "run_install", "run_uninstall", "run_update",
            "run_check_updates", "run_recommendations", "run_app_details",
            "run_list_installed", "run_list_custom_repos", "run_add_custom_repo",
            "run_remove_custom_repo", "run_launch", "run_locate",
            "run_get_storage_info", "run_clean_system", "run_get_essentials",
            "run_import_packages", "run_export_packages", "run_ai_test",
            "run_ai_explain", "run_ai_recommend", "run_ai_analyze_error", "run_ai_pick",
            "run_ai_changelog", "run_ai_cli", "run_ai_conflicts", "run_ai_correct",
            "run_ai_compare", "run_ai_health",
            "run_update_env", "run_save_config", "config.data", "env.check_env", "shutdown"
        }
        if v not in ALLOWED_ACTIONS:
            raise ValueError(f"Forbidden Action: {v}")
        return v

class CLIArguments(BaseModel):
    search: Optional[str] = Field(None, max_length=500)
    install: Optional[str] = Field(None, max_length=500)
    remove: Optional[str] = Field(None, max_length=500)
    update: Optional[str] = Field(None, max_length=500)
    check_updates: bool = False
    list_installed: bool = False
    recommend: bool = False
    details: Optional[str] = None
    clean_system: bool = False
    ai_summary: bool = False
    get_config: bool = False
    set_config: Optional[str] = None
    check_env: bool = False
    bootstrap: bool = False
    list_custom_repos: bool = False
    add_custom_repo: Optional[str] = None
    remove_custom_repo: Optional[str] = None
    ai_explain: Optional[str] = None
    ai_recommend: Optional[str] = None
    ai_analyze_error: Optional[str] = None
    ai_compare: Optional[str] = None
    ai_health: bool = False
    ai_test: bool = False
    ai_pick: bool = False
    ai_correct: Optional[str] = None
    ai_changelog: Optional[str] = None
    ai_cli: Optional[str] = None
    ai_conflicts: Optional[str] = None
    essentials: bool = False
    import_packages: Optional[str] = None
    export_packages: Optional[str] = None
    launch: Optional[str] = None
    locate: Optional[str] = None
    daemon: bool = False
    storage_info: bool = False
    json_mode: bool = Field(default=False, alias="json")
    source: str = "AUR"
    url: Optional[str] = None
    ai_desc: Optional[str] = None
    force_refresh: bool = False

    @field_validator(
        "search", "install", "remove", "update", "details",
        "add_custom_repo", "remove_custom_repo", "ai_explain",
        "ai_recommend", "ai_analyze_error", "ai_compare",
        "ai_correct", "ai_changelog", "ai_cli", "ai_conflicts",
        "import_packages", "export_packages", "launch", "locate"
    )
    @classmethod
    def validate_non_empty_str(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            v_stripped = v.strip()
            if not v_stripped:
                raise ValueError("Argument cannot be empty.")
            return v_stripped
        return v

    @field_validator("add_custom_repo")
    @classmethod
    def validate_add_custom_repo(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            parts = [p.strip() for p in v.split(',', 2)]
            if len(parts) < 3 and parts[0] == "appimage":
                parts = ["appimage", "", parts[1]]
            if len(parts) < 3:
                raise ValueError("Invalid format: type,name,url")
        return v

    @field_validator("remove_custom_repo")
    @classmethod
    def validate_remove_custom_repo(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            parts = [p.strip() for p in v.split(',', 1)]
            if len(parts) < 2:
                raise ValueError("Invalid format: type,name")
        return v

    @field_validator("ai_changelog")
    @classmethod
    def validate_ai_changelog(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            parts = v.split(',')
            if len(parts) < 3:
                raise ValueError("Changelog format: name,current,next")
        return v

    @field_validator("ai_cli")
    @classmethod
    def validate_ai_cli(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            parts = v.split(',')
            if len(parts) < 2:
                raise ValueError("AI CLI format: name,summary")
        return v

async def main():
    setattr(main, "json_mode_active", "--json" in sys.argv)

    # Murphy-proof: Register signal handlers for graceful shutdown
    loop = asyncio.get_running_loop()
    stop_event = asyncio.Event()
    setattr(main, "stop_event", stop_event)

    # Registry for all active OmnistoreBackend instances to ensure cleanup
    active_backends = []

    def _shutdown(sig_name):
        logging.info(f"Received exit signal {sig_name}. Shutting down...")
        stop_event.set()
        # Trigger cleanup for all known backends
        for b in active_backends:
            if hasattr(b, 'executor') and b.executor:
                b.executor.stop()

    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, lambda s=sig: _shutdown(s.name))
        except NotImplementedError:
            # Signal handlers not supported on Windows loop
            pass

    parser = argparse.ArgumentParser(description="Omnistore Backend")
    
    cmd = parser.add_mutually_exclusive_group()
    cmd.add_argument("-S", "--search")
    cmd.add_argument("-I", "--install")
    cmd.add_argument("-R", "--remove")
    cmd.add_argument("-U", "--update")
    cmd.add_argument("-C", "--check-updates", action="store_true")
    cmd.add_argument("-L", "--list-installed", action="store_true")
    cmd.add_argument("--recommend", action="store_true")
    cmd.add_argument("--details")
    cmd.add_argument("--clean-system", action="store_true")
    cmd.add_argument("--ai-summary", action="store_true")
    cmd.add_argument("--get-config", action="store_true")
    cmd.add_argument("--set-config")
    cmd.add_argument("--check-env", action="store_true")
    cmd.add_argument("--bootstrap", action="store_true")
    cmd.add_argument("--list-custom-repos", action="store_true")
    cmd.add_argument("--add-custom-repo")
    cmd.add_argument("--remove-custom-repo")
    cmd.add_argument("--ai-explain")
    cmd.add_argument("--ai-recommend")
    cmd.add_argument("--ai-analyze-error")
    cmd.add_argument("--ai-compare")
    cmd.add_argument("--ai-health", action="store_true")
    cmd.add_argument("--ai-test", action="store_true")
    cmd.add_argument("--ai-pick", action="store_true")
    cmd.add_argument("--ai-correct")
    cmd.add_argument("--ai-changelog")
    cmd.add_argument("--ai-cli")
    cmd.add_argument("--ai-conflicts")
    cmd.add_argument("--essentials", action="store_true")
    cmd.add_argument("--import-packages")
    cmd.add_argument("--export-packages")
    cmd.add_argument("--launch")
    cmd.add_argument("--locate")
    cmd.add_argument("--daemon", action="store_true")
    cmd.add_argument("--storage-info", action="store_true")

    parser.add_argument("--json", action="store_true")
    parser.add_argument("--source", default="AUR")
    parser.add_argument("--url")
    parser.add_argument("--ai-desc")
    parser.add_argument("--force-refresh", action="store_true")

    args = parser.parse_args()
    backend = OmnistoreBackend(json_mode=args.json)
    active_backends.append(backend)

    if not args.json:
        console.print(Panel.fit(f"[bold blue]OmniStore[/bold blue] v0.1.0\n[dim]{get_friendly_message()}[/dim]", border_style="blue"))

    if not sys.platform.startswith("linux") and not args.json:
        console.print("[bold yellow]Warning: OmniStore is optimized for Linux (Arch).[/bold yellow]")

    async def _handle_ai_correct(q):
        res = await backend.ai.suggest_correction(q)
        sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n")

    async def _handle_check_env():
        env_res = await backend.env.check_env()
        sys.stdout.write(json.dumps(env_res, ensure_ascii=False) + "\n")

    async def _handle_bootstrap():
        await backend.env.bootstrap(callback=lambda m: backend._flutter_callback(m, args.json))
        if args.json:
            sys.stdout.write(json.dumps({"status": "success"}) + "\n")

    async def _handle_ai_changelog(p):
        parts = p.split(',')
        res = await backend.ai.summarize_changelog(parts[0], parts[1], parts[2])
        sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n")

    async def _handle_ai_cli(p):
        parts = p.split(',')
        res = await backend.ai.generate_cli_command(parts[0], parts[1])
        sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n")

    async def _handle_ai_conflicts(p):
        if shutil.which("pacman"):
            try:
                async with safe_subprocess("pacman", "-Qq", stdout=asyncio.subprocess.PIPE) as proc:
                    stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5)
                    res = await backend.ai.detect_conflicts(p, stdout.decode().splitlines())
                    sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n")
            except: sys.stdout.write(json.dumps({"response": "Conflict check failed."}) + "\n")
        else:
            sys.stdout.write(json.dumps({"response": "pacman not found, conflict check skipped."}) + "\n")

    async def _handle_ai_compare(p):
        async with backend:
            if backend.manager:
                candidates = await backend.manager.search_all(p)
                target = next((c for c in candidates if c['name'].lower() == p.lower()), candidates[0] if candidates else None)
                if target:
                    res = await backend.ai.compare_variants(p, target.get('variants', []))
                    sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n")
                else: sys.stdout.write(json.dumps({"response": "App not found for comparison."}) + "\n")

    async def _handle_add_custom_repo(raw_repo):
        parts = [p.strip() for p in raw_repo.split(',', 2)]
        if len(parts) < 3 and parts[0] == "appimage":
            parts = ["appimage", "", parts[1]]
        async with backend:
            await backend.run_add_custom_repo(parts[0], parts[1], parts[2], args.json)

    async def _handle_remove_custom_repo(raw_repo):
        parts = [p.strip() for p in raw_repo.split(',', 1)]
        async with backend:
            await backend.run_remove_custom_repo(parts[0], parts[1], args.json)

    async def dispatch():
        """
        Murphy-proof Registry-based Command Dispatcher.
        Ensures that every individual command path is isolated, validated,
        and provides consistent structured output.
        """
        try:
            validated_args = CLIArguments(**vars(args))
        except ValidationError as ve:
            errors = [f"Argument '{e['loc'][0]}' invalid: {e['msg']}" for e in ve.errors()]
            await backend._handle_error("Validation Failure", ValueError("; ".join(errors)), args.json)
            sys.exit(1)

        # 1. Command Registry Definition
        # Each entry is an async lambda or function providing per-command isolation.
        async def _save_config_handler():
            data = sys.stdin.read().strip() or validated_args.set_config
            success = backend.config.save(json.loads(data))
            sys.stdout.write(json.dumps({"status": "success" if success else "error"}) + "\n")

        async def _ai_correct_handler():
            res = await backend.ai.suggest_correction(validated_args.ai_correct)
            sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n")

        REGISTRY = {
            "get_config": lambda: sys.stdout.write(json.dumps(backend.config.data, ensure_ascii=False) + "\n"),
            "set_config": _save_config_handler,
            "search": lambda: backend.run_search(validated_args.search, validated_args.json_mode),
            "install": lambda: backend.run_install(validated_args.install, validated_args.source, validated_args.url, validated_args.json_mode),
            "remove": lambda: backend.run_uninstall(validated_args.remove, validated_args.source, validated_args.json_mode, validated_args.remove),
            "update": lambda: backend.run_update(validated_args.update, validated_args.source, validated_args.json_mode),
            "check_updates": lambda: backend.run_check_updates(validated_args.json_mode),
            "list_installed": lambda: backend.run_list_installed(validated_args.json_mode, validated_args.force_refresh),
            "details": lambda: backend.run_app_details(validated_args.details, validated_args.json_mode),
            "recommend": lambda: backend.run_recommendations(validated_args.json_mode),
            "clean_system": lambda: backend.run_clean_system(validated_args.json_mode),
            "ai_summary": lambda: backend.run_ai_summary(validated_args.json_mode),
            "check_env": _handle_check_env,
            "bootstrap": _handle_bootstrap,
            "list_custom_repos": lambda: backend.run_list_custom_repos(),
            "ai_explain": lambda: backend.run_ai_explain(validated_args.ai_explain, validated_args.ai_desc or ""),
            "ai_recommend": lambda: backend.run_ai_recommend(validated_args.ai_recommend),
            "ai_analyze_error": lambda: backend.run_ai_analyze_error(validated_args.ai_analyze_error),
            "ai_health": backend.run_ai_health_report,
            "ai_test": lambda: backend.run_ai_test(validated_args.json_mode),
            "ai_pick": lambda: backend.run_ai_pick(validated_args.json_mode),
            "ai_correct": _ai_correct_handler,
            "ai_changelog": lambda: _handle_ai_changelog(validated_args.ai_changelog),
            "ai_cli": lambda: _handle_ai_cli(validated_args.ai_cli),
            "ai_conflicts": lambda: _handle_ai_conflicts(validated_args.ai_conflicts),
            "ai_compare": lambda: _handle_ai_compare(validated_args.ai_compare),
            "add_custom_repo": lambda: _handle_add_custom_repo(validated_args.add_custom_repo),
            "remove_custom_repo": lambda: _handle_remove_custom_repo(validated_args.remove_custom_repo),
            "essentials": lambda: backend.run_get_essentials(),
            "import_packages": lambda: backend.run_import_packages(validated_args.import_packages),
            "export_packages": lambda: backend.run_export_packages(validated_args.export_packages),
            "launch": lambda: backend.run_launch(validated_args.launch, validated_args.source, validated_args.json_mode),
            "locate": lambda: backend.run_locate(validated_args.locate, validated_args.source, validated_args.json_mode),
            "storage_info": lambda: backend.run_get_storage_info(validated_args.json_mode),
        }

        # 3. Execution Dispatch
        executed = False
        for flag, handler in REGISTRY.items():
            if getattr(validated_args, flag, None):
                res = handler()
                if inspect.isawaitable(res):
                    await res
                executed = True
                break

        if executed:
            return

        # 4. Logic for complex commands that require specific context management
        try:
            if validated_args.daemon:
                async with backend:
                    # Start local TCP socket server on port 9081
                    server = await asyncio.start_server(
                        lambda r, w: handle_daemon_client(backend, r, w),
                        '127.0.0.1', 9081
                    )
                    logging.info("Python daemon started on 127.0.0.1:9081")
                    async with server:
                        # Murphy-proof: Watchdog and Serve in parallel
                        watchdog_task = asyncio.create_task(daemon_watchdog(stop_event))
                        serve_task = asyncio.create_task(server.serve_forever())
                        wait_task = asyncio.create_task(stop_event.wait())

                        done, pending = await asyncio.wait(
                            [serve_task, wait_task, watchdog_task],
                            return_when=asyncio.FIRST_COMPLETED
                        )

                        for task in pending:
                            task.cancel()

                        logging.info("Stopping daemon server...")

            sys.stdout.flush()
        except Exception as e:
            await backend._handle_error("Dispatch Fatal Error", e, args.json)
            sys.exit(1)

    await dispatch()

if __name__ == "__main__":
    try: asyncio.run(main())
    except KeyboardInterrupt: pass
    except Exception:
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)
