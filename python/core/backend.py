import asyncio
import json
import logging
import sys
import os
import re
import shutil
import inspect
import contextvars
from functools import wraps
from pathlib import Path
from typing import Optional, List, Dict, Any
import aiohttp
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

from core.search.manager import SearchManager
from core.habit_tracker import HabitTracker
from core.recommendation_manager import RecommendationManager
from core.config_loader import ConfigManager
from core.cache_manager import CacheManager
from core.env_manager import EnvManager
from core.subprocess_utils import safe_subprocess
from core.friendly_messages import get_friendly_message
from core.security_validator import SecurityValidator
from core.utils.win_utils import scan_windows_unmanaged_installed, format_bytes, get_directory_size
from core.models import CommandResponse, AppPackage, PackageVariant

# Initial rich console
console = Console(force_terminal=True)

# Murphy-proof: Context-aware output redirection for async daemon concurrency
captured_output_var = contextvars.ContextVar("captured_output", default=None)

# Force all print statements to flush immediately
_orig_print = print

def hijacked_print(*args, **kwargs):
    msg = " ".join(map(str, args))
    buf = captured_output_var.get()
    if buf is not None:
        buf.write(msg + "\n")
        return

    if any(msg.startswith(p) for p in ["[CALLBACK]", "[PROGRESS]", "[SPEED]"]):
        _orig_print(*args, **kwargs, flush=True)
        return

    json_mode = getattr(hijacked_print, "json_mode_active", False)
    if json_mode:
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

def setup_stdout_hijack():
    sys.stdout = SafeStdout(sys.stdout) # type: ignore
    if hasattr(sys.stderr, 'reconfigure'):
        sys.stdout.reconfigure(line_buffering=True, encoding='utf-8', errors='replace') # type: ignore

def safe_command(func):
    """
    Murphy-proof decorator to isolate command failures and prevent backend crashes.
    Enforces timeout, cancellation safety, and structured error reporting.
    """
    @wraps(func)
    async def wrapper(self, *args, **kwargs):
        json_mode = getattr(self, "json_mode", False)
        logging.debug(f"Command execution started: {func.__name__} (args={args}, kwargs={kwargs})")

        # Murphy-proof: Strict command-level timeout protection.
        is_long_running = func.__name__ in ("run_install", "run_uninstall", "run_update", "run_clean_system", "run_bootstrap")
        timeout = kwargs.pop("_timeout", 3600 if is_long_running else 120)

        # Fail-safe: Register command for resource tracking
        command_id = f"{func.__name__}_{id(func)}"
        self._active_commands[command_id] = asyncio.current_task()

        try:
            result = await asyncio.wait_for(func(self, *args, **kwargs), timeout=timeout)
            logging.debug(f"Command execution finished successfully: {func.__name__}")
            return result
        except asyncio.TimeoutError:
            error_msg = f"Murphy-proof: Command {func.__name__} timed out after {timeout}s"
            logging.error(error_msg)
            if json_mode:
                resp = CommandResponse(
                    status="error",
                    error="TimeoutError",
                    message=error_msg,
                    context=func.__name__
                )
                self._output_command_response(resp)
            else:
                hijacked_print(f"[ERROR] {error_msg}")
            return False
        except asyncio.CancelledError:
            logging.warning(f"Command execution cancelled: {func.__name__}")
            if json_mode:
                resp = CommandResponse(
                    status="error",
                    error="CancelledError",
                    message=f"Command {func.__name__} was cancelled.",
                    context=func.__name__
                )
                self._output_command_response(resp)
            raise
        except Exception as e:
            import traceback
            err_trace = traceback.format_exc()
            error_msg = f"Murphy-proof Error in {func.__name__}: {str(e)}"
            logging.error(f"{error_msg}\n{err_trace}")

            if json_mode:
                resp = CommandResponse(
                    status="error",
                    error=type(e).__name__,
                    message=error_msg,
                    context=func.__name__,
                    traceback=err_trace if self.config.get("logging.level") == "DEBUG" else None
                )
                self._output_command_response(resp)
            else:
                try:
                    await self._handle_error(f"Command Error ({func.__name__})", e, json_mode)
                except Exception as inner_e:
                    logging.error(f"Double fault in _handle_error: {inner_e}")
                    hijacked_print(f"[ERROR] {error_msg}")
            return False
        finally:
            self._active_commands.pop(command_id, None)

    return wrapper

class OmnistoreBackend:
    def __init__(self, json_mode: bool = False):
        self.config = ConfigManager()
        self.config.backend = self
        self.cache = CacheManager()
        self.env = EnvManager()
        self.habit_tracker = HabitTracker(backend=self)
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
        self._ref_count = 0
        self._lock = asyncio.Lock()
        # Murphy-proof: Resource and task registry for absolute lifecycle management
        self._task_registry: set[asyncio.Task] = set()
        self._active_commands: Dict[str, asyncio.Task] = {}
        self._temp_resources: List[Any] = []

    def create_task(self, coro) -> asyncio.Task:
        """Murphy-proof: Create a tracked task that is guaranteed to be reaped on backend exit."""
        task = asyncio.create_task(coro)
        self._task_registry.add(task)
        task.add_done_callback(self._task_registry.discard)
        return task

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
        """
        Murphy-proof: Hardened initialization with graceful degradation.
        Ensures that failures in optional components do not block the entire backend.
        """
        async with self._lock:
            # 1. Critical Dependency: Network Session
            session_replaced = False
            try:
                if self.session is None or self.session.closed:
                    # Optimized connector with connection pooling and DNS caching
                    connector = aiohttp.TCPConnector(
                        limit=100,
                        ttl_dns_cache=300,
                        use_dns_cache=True,
                        enable_cleanup_closed=True
                    )
                    self.session = aiohttp.ClientSession(
                        connector=connector,
                        timeout=aiohttp.ClientTimeout(total=60, connect=10),
                        raise_for_status=False
                    )
                    session_replaced = True
            except Exception as e:
                logging.error(f"Murphy-proof: Critical failure initializing aiohttp session: {e}")
                # Fault isolation: We continue even if network is down

            # 2. Lazy Component Injection
            try:
                if self.recommender is None or session_replaced:
                    self.recommender = RecommendationManager(self.session, self.habit_tracker, backend=self)
            except Exception as e:
                logging.error(f"Murphy-proof: Graceful degradation: Failed to initialize RecommendationManager: {e}")

            try:
                if self.manager is None or session_replaced:
                    self.manager = SearchManager(
                        self.config, self.session, self.habit_tracker,
                        recommender=self.recommender, cache_manager=self.cache,
                        ai_assistant=self.ai
                    )
            except Exception as e:
                logging.error(f"Murphy-proof: Graceful degradation: Failed to initialize SearchManager: {e}")

        return self

    async def __aenter__(self):
        await self.initialize()
        async with self._lock:
            self._ref_count += 1
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        async with self._lock:
            if self._ref_count > 0:
                self._ref_count -= 1
            if self._ref_count > 0:
                return

        try:
            # Murphy-proof: Aggressive task cleanup
            if self._task_registry:
                logging.info(f"OmnistoreBackend: Cleaning up {len(self._task_registry)} registered tasks.")
                for task in list(self._task_registry):
                    if not task.done():
                        task.cancel()

                # Await all tasks with a short timeout to prevent shutdown hang
                try:
                    await asyncio.wait_for(
                        asyncio.gather(*self._task_registry, return_exceptions=True),
                        timeout=5.0
                    )
                except (asyncio.TimeoutError, Exception):
                    logging.warning("OmnistoreBackend: Some tasks failed to terminate gracefully during cleanup.")
                self._task_registry.clear()

            if self._executor:
                try: self._executor.stop()
                except: pass
                self._executor = None

            if self.session and not self.session.closed:
                # Increased timeout for session closure to ensure all pending requests are finished or dropped
                try: await asyncio.wait_for(self.session.close(), timeout=5.0)
                except: pass
                self.session = None

            if self._ai:
                try: await self._ai.close()
                except: pass

            # Murphy-proof: Cleanup temporary resources (files, etc.)
            for res in self._temp_resources:
                try:
                    if hasattr(res, "close"): res.close()
                    elif os.path.exists(str(res)): os.remove(str(res))
                except: pass
            self._temp_resources.clear()

            self.manager = None
            self.recommender = None
            self._ai = None
            self._updater = None
            self._repo_manager = None
            self._essentials = None

        except Exception as e:
            logging.error(f"Murphy-proof Critical: Cleanup failure: {e}")

    async def _flutter_callback(self, msg: str, json_mode: bool = False, level: Optional[str] = None):
        if level is None:
            if msg.startswith(("[ERROR]", "[Error]")): level = "ERROR"
            elif any(msg.startswith(p) for p in ["[INFO]", "[Status]", "[Executor]"]): level = "INFO"
            elif msg.startswith("[PROGRESS]"): level = "PROGRESS"
            elif msg.startswith("[DEBUG]"): level = "DEBUG"
            else: level = "INFO"

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
            if level == "ERROR": logging.error(clean_msg)
            elif level == "PROGRESS":
                if not clean_msg.isdigit(): logging.info(f"Progress: {clean_msg}%")
            else: logging.info(clean_msg)

    @safe_command
    async def run_search(self, query: str, json_mode: bool = False) -> Any:
        """Murphy-proof search command with structured response."""
        valid_query = SecurityValidator.validate_string(query, "Search Query")
        async with self:
            if not self.manager:
                raise RuntimeError("SearchManager is not initialized.")

            results = await asyncio.wait_for(self.manager.search_all(valid_query), timeout=45)
            if results is None:
                results = []

            # Standardize and type-check results
            typed_results = self._to_app_packages(results)

            if json_mode:
                resp = CommandResponse(
                    status="success",
                    response=[item.model_dump(exclude_none=True) for item in typed_results],
                    context="run_search"
                )
                self._output_command_response(resp)
            else:
                self._output_pretty(query, [item.model_dump() for item in typed_results])

            return typed_results

    @safe_command
    async def run_install(self, name: str, source: str, url: Optional[str] = None, json_mode: bool = False) -> Any:
        """
        Murphy-proof installation command.
        Enforces strict input validation and returns structured CommandResponse.
        """
        valid_name = SecurityValidator.validate_string(name, "Package Name")
        valid_source = SecurityValidator.validate_string(source, "Source")
        valid_url = SecurityValidator.validate_url(url) if url else None

        self.is_action = True
        package_data = {"name": valid_name, "id": valid_name, "source": valid_source, "url": valid_url}

        async with self:
            if self.manager and self.manager.habit_tracker:
                self.manager.habit_tracker.record_install(valid_name, valid_source)

            async def cb(m): await self._flutter_callback(m, json_mode)

            if not json_mode:
                console.print(Panel(f"Installing [bold green]{valid_name}[/bold green] from [cyan]{valid_source}[/cyan]", border_style="green"))

            success = await self.executor.install(package_data, callback=cb)

            if success:
                self.cache.invalidate_installed_cache()
                if not json_mode:
                    console.print(Panel(f"Successfully installed [bold green]{valid_name}[/bold green]! 🎉", border_style="green"))
                    console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")

            if json_mode:
                resp = CommandResponse(
                    status="success" if success else "error",
                    response=success,
                    message=f"Installation {'succeeded' if success else 'failed'} for {valid_name}"
                )
                self._output_command_response(resp)
            return success

    @safe_command
    async def run_uninstall(self, package_name: str, source: str, json_mode: bool = False, flag: str = "-R") -> Any:
        """Murphy-proof uninstallation command."""
        valid_name = SecurityValidator.validate_string(package_name, "Package Name")
        valid_source = SecurityValidator.validate_string(source, "Source")
        valid_flag = SecurityValidator.validate_action_flag(flag)

        self.is_action = True
        package_data = {"name": valid_name, "id": valid_name, "source": valid_source, "flag": valid_flag}

        async with self:
            async def cb(m): await self._flutter_callback(m, json_mode)

            if not json_mode:
                console.print(Panel(f"Uninstalling [bold red]{valid_name}[/bold red] from [cyan]{valid_source}[/cyan]", border_style="red"))

            success = await self.executor.uninstall(package_data, callback=cb)

            if success:
                self.cache.invalidate_installed_cache()
                if not json_mode:
                    console.print(Panel(f"Successfully uninstalled [bold red]{valid_name}[/bold red]! ✨", border_style="green"))
                    console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")

            if json_mode:
                resp = CommandResponse(
                    status="success" if success else "error",
                    response=success,
                    message=f"Uninstallation {'succeeded' if success else 'failed'} for {valid_name}"
                )
                self._output_command_response(resp)
            return success

    @safe_command
    async def run_update(self, package_name: str, source: str, json_mode: bool = False) -> Any:
        """Murphy-proof update command."""
        valid_name = SecurityValidator.validate_string(package_name, "Package Name")
        valid_source = SecurityValidator.validate_string(source, "Source")

        self.is_action = True
        package_data = {"name": valid_name, "id": valid_name, "source": valid_source}

        async with self:
            async def cb(m): await self._flutter_callback(m, json_mode)

            if not json_mode:
                target = "all packages" if valid_name == "all" else f"[bold green]{valid_name}[/bold green]"
                console.print(Panel(f"Updating {target} via [cyan]{valid_source}[/cyan]", border_style="blue"))

            success = await self.executor.update(package_data, callback=cb)

            if success:
                self.cache.invalidate_installed_cache()
                if not json_mode:
                    console.print(Panel(f"Update completed! 🎉", border_style="green"))
                    console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")

            if json_mode:
                resp = CommandResponse(
                    status="success" if success else "error",
                    response=success,
                    message=f"Update {'completed' if success else 'failed'} for {valid_name}"
                )
                self._output_command_response(resp)
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
            table.add_column("Source", style="cyan"); table.add_column("Package Name", style="bold green")
            table.add_column("Current", style="red"); table.add_column("New", style="green")
            for u in updates: table.add_row(u['source'], u['name'], u['current_version'], u['new_version'])
            console.print(table); console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")

    @safe_command
    async def run_recommendations(self, json_mode: bool = False):
        async with self:
            if not self.recommender: raise RuntimeError("RecommendationManager not initialized.")
            sources = list(self.manager.sources.values()) if self.manager else []
            results = await self.recommender.get_recommendations(sources=sources)
            if json_mode: sys.stdout.write(json.dumps(results, ensure_ascii=False) + "\n"); sys.stdout.flush()
            else:
                if isinstance(results, dict):
                    for category, apps in results.items():
                        hijacked_print(f"\n[{category}]")
                        for app in apps:
                            if isinstance(app, dict): hijacked_print(f"  推荐: {app.get('name')} ({app.get('id')})")
                elif isinstance(results, list):
                    for app in results:
                        if isinstance(app, dict): hijacked_print(f"推荐: {app.get('name')} ({app.get('id')})")

    @safe_command
    async def run_app_details(self, app_id: str, json_mode: bool = False, source: Optional[str] = None) -> Any:
        """Murphy-proof app details command with structured response."""
        valid_id = SecurityValidator.validate_strict_id(app_id, "App ID")
        valid_source = SecurityValidator.validate_string(source, "Source") if source else None

        async with self:
            if not self.recommender or not self.manager:
                raise RuntimeError("Managers are not initialized.")

            details: Dict[str, Any] = {}
            source_key = (valid_source or "").lower().replace("builtin.", "")
            if source_key == "native":
                source_key = "pacman"

            source_obj = self.manager.sources.get(source_key) if source_key else None
            if source_obj and source_obj.capabilities.get("details"):
                try:
                    details = await asyncio.wait_for(source_obj.get_details(valid_id), timeout=30)
                except Exception as exc:
                    logging.debug(f"Plugin details failed for {source_key}:{valid_id}: {exc}")
                    details = {}

            if not details:
                details = await asyncio.wait_for(
                    self.recommender.get_details(valid_id) if "." in valid_id else self.recommender.find_metadata(valid_id),
                    timeout=30
                )

            search_name = details.get("name") or valid_id.split(".")[-1]
            # Defense: Strictly sanitize search_name for safety
            search_name = SecurityValidator.validate_string(search_name, "Search Name")

            variants_results = await asyncio.wait_for(self.manager.search_all(search_name), timeout=30)
            norm_target = self.manager._normalize_app_name(search_name)
            matched_app = next((res for res in variants_results if self.manager._normalize_app_name(res['name']) == norm_target), None)

            if matched_app:
                if not details:
                    details.update(matched_app)
                details["variants"] = matched_app.get("variants", [])
                if not details.get("description") or len(details.get("description")) < 10:
                    details["description"] = matched_app.get("description", "")

            async def _fetch_variant_info(variant):
                v_source = variant.get('source')
                if not v_source: return
                if v_source in ("Native", "Pacman", "AUR"):
                    if not sys.platform.startswith("linux"): return
                    try:
                        binary = "pacman" if v_source in ("Native", "Pacman") else "yay"
                        if not shutil.which(binary): return
                        flag = "-Si" if v_source in ("Native", "Pacman") else "-Sii"
                        pkg_name = variant.get('name', search_name)
                        # Defense: Ensure pkg_name is safe
                        pkg_name = SecurityValidator.validate_string(pkg_name, "Package Name")
                        cmd = [binary, flag, pkg_name]
                        async with safe_subprocess(*cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL, env={**os.environ, "LC_ALL": "C"}) as proc:
                            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5)
                            if stdout:
                                info = stdout.decode()
                                if (m := re.search(r"(?:Depends On|Depends)\s+:\s+(.*)", info)): variant["depends"] = m.group(1).split()
                                if (m := re.search(r"Download Size\s+:\s+(.*)", info)): variant["download_size"] = m.group(1).strip()
                                if (m := re.search(r"Installed Size\s+:\s+(.*)", info)): variant["installed_size"] = m.group(1).strip()
                    except: pass

            variant_tasks = [_fetch_variant_info(v) for v in details.get("variants", [])]
            if variant_tasks:
                await asyncio.wait_for(asyncio.gather(*variant_tasks, return_exceptions=True), timeout=20)

            # Standardize output model
            try:
                typed_details = AppPackage(**details)
                if json_mode:
                    resp = CommandResponse(
                        status="success",
                        response=typed_details.model_dump(exclude_none=True),
                        context="run_app_details"
                    )
                    self._output_command_response(resp)
                return typed_details
            except Exception as e:
                logging.error(f"AppPackage validation failed for details of {valid_id}: {e}")
                if json_mode:
                    raise
                return details

    @safe_command
    async def run_list_installed(self, json_mode: bool = False, force_refresh: bool = False, include_unmanaged: bool = True) -> Any:
        """Murphy-proof list installed apps command with structured response."""
        if not force_refresh:
            cached = self.cache.get_installed_packages() if self.cache else None
            if cached:
                if json_mode:
                    resp = CommandResponse(status="success", response=cached, context="run_list_installed")
                    self._output_command_response(resp)
                else:
                    self._output_installed_pretty(cached)
                return cached

        installed_list = []
        async with self:
            sources = list(self.manager.sources.values()) if self.manager else []

            async def scan_source(source_obj):
                try:
                    if source_obj.capabilities.get("list_installed"):
                        return await asyncio.wait_for(source_obj.list_installed(), timeout=30)
                except Exception as e:
                    logging.debug(f"list_installed failed for {getattr(source_obj, 'name', 'unknown')}: {e}")
                return []

            results = await asyncio.gather(*[scan_source(source) for source in sources], return_exceptions=True)
            for r in results:
                if isinstance(r, list):
                    installed_list.extend(r)

            if include_unmanaged and sys.platform == "win32":
                installed_list.extend(await scan_windows_unmanaged_installed(self.manager))

            installed_list = self._merge_installed_apps(installed_list)

            if self.recommender:
                enrich_targets = [app for app in installed_list if not app.get('icon')]
                async def _enrich_app(app):
                    try:
                        metadata = await self.recommender.find_metadata(app['name'], use_network=app.get('_use_network', True))
                        if metadata:
                            if metadata.get('icon'): app['icon'] = metadata['icon']
                            if metadata.get('description'): app['description'] = metadata['description']
                    except: pass

                if enrich_targets:
                    for i, app in enumerate(enrich_targets): app['_use_network'] = (i < 10)
                    await asyncio.gather(*[_enrich_app(app) for app in enrich_targets[:10]], return_exceptions=True)
                    for app in enrich_targets: app.pop('_use_network', None)

            typed_list = [item.model_dump(exclude_none=True) for item in self._to_app_packages(installed_list)]

            if json_mode:
                resp = CommandResponse(status="success", response=typed_list, context="run_list_installed")
                self._output_command_response(resp)
            else:
                self._output_installed_pretty(typed_list)

            if self.cache:
                self.cache.save_installed_packages(typed_list)

            return typed_list

    @safe_command
    async def run_list_installed_sources(self, json_mode: bool = False, force_refresh: bool = False, include_unmanaged: bool = True):
        return await self.run_list_installed(
            json_mode=json_mode,
            force_refresh=force_refresh,
            include_unmanaged=include_unmanaged,
        )

    @safe_command
    async def run_list_plugins(self, json_mode: bool = False):
        async with self:
            registry = self.manager.plugin_registry if self.manager else None
            plugins = registry.list_plugins() if registry else []
            if json_mode:
                sys.stdout.write(json.dumps(plugins, ensure_ascii=False) + "\n"); sys.stdout.flush()
            else:
                table = Table(title="OmniStore Plugins")
                table.add_column("ID"); table.add_column("Name"); table.add_column("Enabled"); table.add_column("Available"); table.add_column("Builtin")
                for p in plugins:
                    table.add_row(p["id"], p["name"], str(p["enabled"]), str(p["available"]), str(p["builtin"]))
                console.print(table)
            return plugins

    @safe_command
    async def run_set_plugin_enabled(self, plugin_id: str, enabled: bool, json_mode: bool = False) -> bool:
        SecurityValidator.validate_string(plugin_id, "Plugin ID")
        async with self:
            ok = bool(self.manager and self.manager.plugin_registry and self.manager.plugin_registry.enable(plugin_id, enabled))
            if self.cache:
                self.cache.invalidate_installed_cache()
            if json_mode:
                sys.stdout.write(json.dumps({"status": "success" if ok else "error", "plugin_id": plugin_id, "enabled": enabled}) + "\n"); sys.stdout.flush()
            return ok

    @safe_command
    async def run_remove_plugin(self, plugin_id: str, json_mode: bool = False) -> bool:
        SecurityValidator.validate_string(plugin_id, "Plugin ID")
        if self.executor and self.executor.is_running:
            if json_mode:
                sys.stdout.write(json.dumps({"status": "error", "message": "A task is currently running"}) + "\n"); sys.stdout.flush()
            return False
        async with self:
            ok = bool(self.manager and self.manager.plugin_registry and self.manager.plugin_registry.remove(plugin_id))
            if self.cache:
                self.cache.invalidate_installed_cache()
            if json_mode:
                sys.stdout.write(json.dumps({"status": "success" if ok else "error", "plugin_id": plugin_id}) + "\n"); sys.stdout.flush()
            return ok

    def _merge_installed_apps(self, apps: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Murphy-proof: Robust merging of installed app metadata with malformed data protection."""
        merged: Dict[str, Dict[str, Any]] = {}
        for app in apps:
            if not isinstance(app, dict):
                continue
            name = str(app.get("name") or app.get("id") or "").strip()
            if not name:
                continue
            try:
                key = self._installed_key(app)
                if key not in merged:
                    merged[key] = app.copy()
                    merged[key].setdefault("variants", [])
                    continue
                target = merged[key]
                # Merge variants carefully
                existing_variants = target.setdefault("variants", [])
                for variant in app.get("variants", []):
                    if not isinstance(variant, dict): continue
                    if variant not in existing_variants:
                        existing_variants.append(variant)

                # Merge other fields
                for field in (
                    "download_size",
                    "installed_size",
                    "disk_size",
                    "size_confidence",
                    "size_source",
                    "install_location",
                ):
                    if not target.get(field) and app.get(field):
                        target[field] = app[field]

                # If current item is managed and target is not, prefer managed metadata
                if app.get("managed") and not target.get("managed"):
                    target_variants = target.get("variants", [])
                    target.update({k: v for k, v in app.items() if k != "variants"})
                    target["variants"] = target_variants
            except Exception as e:
                logging.error(f"Murphy-proof: Error merging app {name}: {e}")
                continue

        return sorted(merged.values(), key=lambda item: str(item.get("name", "")).lower())

    def _installed_key(self, app: Dict[str, Any]) -> str:
        name = str(app.get("name") or app.get("id") or "").strip().lower()
        version = str(app.get("version") or "").strip().lower()
        if name:
            return f"name:{name}:{version}"
        publisher = str(app.get("developer") or "").lower()
        location = str(app.get("install_location") or "").lower()
        return f"unmanaged:{publisher}:{location}:{str(app.get('id') or '').lower()}"

    @safe_command
    async def run_list_custom_repos(self):
        flatpaks = await self.repo_manager.list_flatpak_remotes()
        pacmans = await self.repo_manager.list_pacman_repos()
        appimages = self.repo_manager.list_appimage_feeds()
        result = {"flatpak": flatpaks, "pacman": pacmans, "appimage": [{"name": Path(url).stem, "url": url} for url in appimages],
            "config_flatpak": self.config.get("custom_repos.flatpak", []), "config_pacman": self.config.get("custom_repos.pacman", [])}
        sys.stdout.write(json.dumps(result, ensure_ascii=False) + "\n"); sys.stdout.flush()

    @safe_command
    async def run_add_custom_repo(self, repo_type: str, name: str, url: str, json_mode: bool = False) -> bool:
        SecurityValidator.validate_string(repo_type, "Repo Type")
        SecurityValidator.validate_string(name, "Repo Name")
        SecurityValidator.validate_url(url)

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
        SecurityValidator.validate_string(repo_type, "Repo Type")
        SecurityValidator.validate_string(name, "Repo Name")

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
    async def run_ai_explain(self, app_name: str, app_description: str = "", json_mode: bool = False):
        """Murphy-proof AI explain command."""
        valid_name = SecurityValidator.validate_string(app_name, "App Name")
        safe_desc = str(app_description or "")[:10000]

        async with self:
            res = await self.ai.explain_app(valid_name, safe_desc)
            if json_mode:
                self._output_command_response(CommandResponse(status="success", response=res, context="ai_explain"))
            else:
                hijacked_print(res)
            return res

    @safe_command
    async def run_ai_recommend(self, prompt: str, json_mode: bool = False):
        """Murphy-proof AI recommend command."""
        valid_prompt = SecurityValidator.validate_string(prompt, "AI Prompt")
        async with self:
            if not self.manager:
                raise RuntimeError("SearchManager not initialized.")
            keywords = valid_prompt.split()
            candidates = await self.manager.search_all(keywords[0] if keywords else valid_prompt)
            res = await self.ai.recommend_apps(valid_prompt, candidates)
            if json_mode:
                self._output_command_response(CommandResponse(status="success", response=res, context="ai_recommend"))
            else:
                hijacked_print(res)
            return res

    @safe_command
    async def run_ai_analyze_error(self, error_log: str, json_mode: bool = False):
        """Murphy-proof AI error analysis."""
        safe_log = str(error_log or "")[:50000]
        async with self:
            res = await self.ai.analyze_error(safe_log)
            if json_mode:
                self._output_command_response(CommandResponse(status="success", response=res, context="ai_analyze_error"))
            else:
                hijacked_print(res)
            return res

    @safe_command
    async def run_ai_changelog(self, name: str, current: str, next_v: str, json_mode: bool = False):
        """Murphy-proof AI changelog summary."""
        v_name = SecurityValidator.validate_string(name, "App Name")
        v_cur = SecurityValidator.validate_string(current, "Current Version")
        v_next = SecurityValidator.validate_string(next_v, "Next Version")

        async with self:
            res = await self.ai.summarize_changelog(v_name, v_cur, v_next)
            if json_mode:
                self._output_command_response(CommandResponse(status="success", response=res, context="ai_changelog"))
            else:
                hijacked_print(res)
            return res

    @safe_command
    async def run_ai_cli(self, name: str, summary: str, json_mode: bool = False):
        """Murphy-proof AI CLI command generation."""
        v_name = SecurityValidator.validate_string(name, "App Name")
        v_summary = SecurityValidator.validate_string(summary, "Summary")

        async with self:
            res = await self.ai.generate_cli_command(v_name, v_summary)
            if json_mode:
                self._output_command_response(CommandResponse(status="success", response=res, context="ai_cli"))
            else:
                hijacked_print(res)
            return res

    @safe_command
    async def run_ai_conflicts(self, name: str, json_mode: bool = False):
        """Murphy-proof AI conflict detection."""
        v_name = SecurityValidator.validate_string(name, "App Name")

        async with self:
            packages = []
            if shutil.which("pacman"):
                try:
                    async with safe_subprocess("pacman", "-Qq", stdout=asyncio.subprocess.PIPE) as proc:
                        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5)
                        packages = stdout.decode().splitlines()
                except Exception as e:
                    logging.debug(f"pacman package scan failed for AI conflicts: {e}")

            res = await self.ai.detect_conflicts(v_name, packages)
            if json_mode:
                self._output_command_response(CommandResponse(status="success", response=res, context="ai_conflicts"))
            else:
                hijacked_print(res)
            return res

    @safe_command
    async def run_ai_correct(self, query: str, json_mode: bool = False):
        """Murphy-proof AI query correction."""
        v_query = SecurityValidator.validate_string(query, "Query")
        async with self:
            res = await self.ai.suggest_correction(v_query)
            if json_mode:
                self._output_command_response(CommandResponse(status="success", response=res, context="ai_correct"))
            else:
                hijacked_print(res)
            return res

    @safe_command
    async def run_ai_compare(self, name: str, json_mode: bool = False):
        """Murphy-proof AI variant comparison."""
        v_name = SecurityValidator.validate_string(name, "App Name")
        async with self:
            if not self.manager:
                raise RuntimeError("Search manager not initialized.")

            candidates = await self.manager.search_all(v_name)
            target = next((c for c in candidates if c['name'].lower() == v_name.lower()), candidates[0] if candidates else None)

            if target:
                res = await self.ai.compare_variants(v_name, target.get('variants', []))
            else:
                res = "App not found for comparison."

            if json_mode:
                self._output_command_response(CommandResponse(status="success", response=res, context="ai_compare"))
            else:
                hijacked_print(res)
            return res

    @safe_command
    async def run_ai_health(self, json_mode: bool = False):
        """Murphy-proof AI system health report."""
        async with self:
            status = await self.env.check_env()
            status["orphaned_count"] = 0
            if sys.platform.startswith("linux") and shutil.which("pacman"):
                try:
                    async with safe_subprocess("pacman", "-Qtdq", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5)
                        status["orphaned_count"] = len(stdout.decode().splitlines())
                except: pass

            res = await self.ai.generate_health_report(status)
            if json_mode:
                self._output_command_response(CommandResponse(status="success", response=res, context="ai_health"))
            else:
                hijacked_print(res)
            return res

    @safe_command
    async def run_get_essentials(self):
        res = self.essentials.get_essentials()
        sys.stdout.write(json.dumps(res, ensure_ascii=False) + "\n"); sys.stdout.flush()

    @safe_command
    async def run_import_packages(self, filepath: str):
        SecurityValidator.validate_path(filepath, "Import Path")
        res = self.essentials.import_from_file(filepath)
        sys.stdout.write(json.dumps(res, ensure_ascii=False) + "\n"); sys.stdout.flush()

    @safe_command
    async def run_export_packages(self, filepath: str):
        SecurityValidator.validate_path(filepath, "Export Path")
        installed = []
        is_linux = sys.platform.startswith("linux")
        commands = []
        if is_linux:
            commands.extend([
                (["pacman", "-Qqne"], "Native"),
                (["yay", "-Qm"], "AUR")
            ])
        commands.append((["flatpak", "list", "--app", "--columns=application"], "Flatpak"))

        for cmd, src in commands:
            if not shutil.which(cmd[0]): continue
            try:
                async with safe_subprocess(*cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                    stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
                    if stdout:
                        for line in stdout.decode().strip().splitlines():
                            if line: installed.append({"name": line.split()[0], "source": src})
            except Exception as e: logging.debug(f"Export {src} failed: {e}")
        export_dir = os.path.dirname(os.path.abspath(filepath))
        if export_dir: os.makedirs(export_dir, exist_ok=True)
        with open(filepath, 'w', encoding='utf-8') as f: json.dump(installed, f, ensure_ascii=False, indent=2)
        if self.json_mode: sys.stdout.write(json.dumps({"status": "success", "count": len(installed)}) + "\n")
        else: console.print(Panel(f"Successfully exported {len(installed)} packages to {filepath}", border_style="green"))
        sys.stdout.flush()

    @safe_command
    async def run_launch(self, name: str, source: str, json_mode: bool = False) -> bool:
        SecurityValidator.validate_string(name, "App Name")
        SecurityValidator.validate_string(source, "Source")
        async with self:
            src = source.lower()
            if src == "native": src = "pacman"
            if self.manager and src in self.manager.sources:
                success = await self.manager.sources[src].launch({"name": name, "id": name})
                if json_mode: sys.stdout.write(json.dumps({"status": "success" if success else "error"}) + "\n")
                return success
            return False

    @safe_command
    async def run_locate(self, name: str, source: str, json_mode: bool = False) -> bool:
        SecurityValidator.validate_string(name, "App Name")
        SecurityValidator.validate_string(source, "Source")
        async with self:
            src = source.lower()
            if src == "native": src = "pacman"
            if self.manager and src in self.manager.sources:
                success = await self.manager.sources[src].locate({"name": name, "id": name})
                if json_mode: sys.stdout.write(json.dumps({"status": "success" if success else "error"}) + "\n")
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
                        if entry.is_file(): pacman_cache += entry.stat().st_size
                except: pass
            flatpak_cache = 0
            flatpak_paths = [os.path.expanduser("~/.local/share/flatpak"), os.path.expanduser("~/.var/app")]
            for p in flatpak_paths:
                if os.path.exists(p):
                    try:
                        for root, _, files in os.walk(p):
                            for file in files: flatpak_cache += os.path.getsize(os.path.join(root, file))
                    except: pass
            omnistore_cache = 0
            omnistore_paths = [os.path.expanduser("~/.config/omnistore"), os.path.expanduser("~/.cache/omnistore")]
            for p in omnistore_paths:
                if os.path.exists(p):
                    try:
                        for root, _, files in os.walk(p):
                            for file in files: omnistore_cache += os.path.getsize(os.path.join(root, file))
                    except: pass
            info = {"disk_total": total, "disk_used": used, "disk_free": free, "pacman_cache": pacman_cache,
                "flatpak_cache": flatpak_cache, "omnistore_cache": omnistore_cache, "total_cache": pacman_cache + flatpak_cache + omnistore_cache}
            if json_mode: sys.stdout.write(json.dumps(info) + "\n")
            else:
                hijacked_print(f"Disk Total: {total / (1024**3):.2f} GB")
                hijacked_print(f"Disk Free: {free / (1024**3):.2f} GB")
                hijacked_print(f"Total Cache: {(pacman_cache + flatpak_cache + omnistore_cache) / (1024**2):.2f} MB")
            sys.stdout.flush()
            return info

    @safe_command
    async def run_clean_system(self, json_mode: bool = False) -> Any:
        """Murphy-proof system cleanup command."""
        async def cb(m): await self._flutter_callback(m, json_mode)

        if not sys.platform.startswith("linux"):
            await cb("[INFO] System cleanup is only supported on Linux. Skipping.")
            if json_mode:
                self._output_command_response(CommandResponse(status="success", message="Unsupported platform"))
            return True

        async with self:
            if not json_mode: console.print(Panel("Starting System Cleanup", border_style="blue"))
            if shutil.which("pacman") is None:
                await cb("[INFO] pacman not found, skipping.")
                return True

            await cb("[INFO] Detecting orphan packages...")
            orphans = []
            try:
                async with safe_subprocess("pacman", "-Qtdq", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE) as proc:
                    stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
                    orphans = [o.strip() for o in stdout.decode().strip().splitlines() if o.strip()]
            except: pass

            if orphans:
                await cb(f"[INFO] Cleaning {len(orphans)} orphans...")
                if await self.executor._ensure_privileged(cb):
                    async with safe_subprocess("sudo", "pacman", "-Rs", "--noconfirm", *orphans) as p:
                        try: await asyncio.wait_for(p.wait(), timeout=60)
                        except asyncio.TimeoutError: pass

            await cb("[INFO] Cleaning package cache...")
            if await self.executor._ensure_privileged(cb):
                async with safe_subprocess("sudo", "pacman", "-Scc", stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT) as p:
                    try:
                        p.stdin.write(b"y\ny\n"); await p.stdin.drain(); p.stdin.close()
                        while True:
                            line_bytes = await asyncio.wait_for(p.stdout.readline(), timeout=5)
                            if not line_bytes: break
                            line = line_bytes.decode('utf-8', errors='ignore').strip()
                            if line: await cb(f"[INFO] {line}")
                        await asyncio.wait_for(p.wait(), timeout=60)
                    except (asyncio.TimeoutError, Exception):
                        pass

            await cb("[INFO] System cleanup finished!")
            if json_mode:
                self._output_command_response(CommandResponse(status="success", message="System cleanup finished"))
            return True

    @safe_command
    async def run_ai_summary(self, json_mode: bool = False):
        res = await self.ai.summarize_project()
        if json_mode: sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()
        else: hijacked_print(f"AI Summary:\n{res}")

    @safe_command
    async def run_save_config(self, config_data: dict):
        return self.config.save(config_data)

    @safe_command
    async def run_update_env(self, env_vars: dict, json_mode: bool = False):
        import os
        for k, v in env_vars.items():
            if v is not None: os.environ[k] = str(v)
            elif k in os.environ: del os.environ[k]
        self.config.current_config = self.config.load()
        if json_mode: sys.stdout.write(json.dumps({"status": "success"}, ensure_ascii=False) + "\n"); sys.stdout.flush()
        return True

    @safe_command
    async def run_ai_test(self, json_mode: bool = False):
        self.config.current_config = self.config.load()
        res = await self.ai.test_connection()
        if json_mode: sys.stdout.write(json.dumps({"status": "success" if res == "success" else "error", "response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()
        else: hijacked_print(f"AI Connection Test:\n{res}")

    @safe_command
    async def run_ai_pick(self, json_mode: bool = False):
        async with self:
            if not self.recommender: raise RuntimeError("RecommendationManager not initialized.")
            recs = await self.recommender.get_recommendations()
            candidates = []
            for key in ['trending', 'featured', 'for_you']: candidates.extend(recs.get(key, []))
            seen = set(); unique_candidates = []
            for c in candidates:
                if c['name'] not in seen: seen.add(c['name']); unique_candidates.append(c)
            if unique_candidates:
                filtered = [c for c in unique_candidates if c.get('name') and c.get('description')] or unique_candidates
                res = await self.ai.pick_of_the_day(filtered[:15])
                if "PICK_JSON:" not in res and filtered: res += f"\nPICK_JSON: [\"{filtered[0]['name']}\"]"
            else: res = "Today's recommendation: OmniStore itself!"
            sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()

    def _output_command_response(self, resp: CommandResponse):
        """Murphy-proof: Standardized output for all CommandResponse models."""
        try:
            # Ensure we start on a new line and flush for absolute clarity
            sys.stdout.write("\n" + resp.model_dump_json(exclude_none=True) + "\n")
            sys.stdout.flush()
        except Exception as e:
            logging.error(f"Critical: Failed to serialize CommandResponse: {e}")
            # Final fallback
            sys.stdout.write(f"\n{{\"status\":\"error\",\"error\":\"SerializationError\",\"message\":\"{str(e)}\"}}\n")
            sys.stdout.flush()

    async def _handle_error(self, context: str, exception: Exception, json_mode: bool):
        error_msg = f"{context}: {str(exception)}"
        if json_mode:
            resp = CommandResponse(
                status="error",
                error=type(exception).__name__,
                message=error_msg,
                context=context
            )
            self._output_command_response(resp)
        else:
            logging.error(error_msg)

    def _to_app_packages(self, results: List[Dict]) -> List[AppPackage]:
        """Murphy-proof: Convert raw dictionaries to validated AppPackage models."""
        output = []
        for item in results:
            if not isinstance(item, dict):
                continue
            try:
                # Map loose dict fields to AppPackage model with defaults
                data = {
                    "name": str(item.get("name") or "Unknown"),
                    "id": str(item.get("id") or item.get("name") or "unknown"),
                    "description": str(item.get("description", "")),
                    "installed": bool(item.get("installed", False) or item.get("is_installed", False)),
                    "version": str(item.get("last_version") or item.get("version") or "N/A"),
                    "primary_source": str(item.get("primary_source") or item.get("source") or "Native"),
                    "developer": item.get("developer"),
                    "icon": item.get("icon"),
                    "screenshots": item.get("screenshots", []),
                    "score": int(item.get("score", 0)),
                    "is_exact_match": bool(item.get("is_exact_match", False)),
                    "install_location": item.get("install_location"),
                    "uninstall_string": item.get("uninstall_string"),
                    "size_confidence": item.get("size_confidence"),
                    "size_source": item.get("size_source"),
                    "disk_size": item.get("disk_size"),
                    "installed_size": item.get("installed_size"),
                    "managed": bool(item.get("managed", True)),
                    "variants": [PackageVariant(**v) if isinstance(v, dict) else v for v in item.get("variants", [])]
                }
                output.append(AppPackage(**data))
            except Exception as e:
                logging.error(f"Murphy-proof: Failed to validate AppPackage '{item.get('name')}': {e}")
        return output

    def _output_json(self, results):
        """Legacy JSON output wrapper."""
        typed_results = self._to_app_packages(results)
        output = [item.model_dump(exclude_none=True) for item in typed_results]
        sys.stdout.write(json.dumps(output, ensure_ascii=False) + "\n")
        sys.stdout.flush()

    def _output_pretty(self, query, results):
        if not results: console.print(Panel(f"No results found for [bold cyan]'{query}'[/bold cyan]", border_style="yellow")); return
        table = Table(title=f"Search Results: {query}", show_header=True, header_style="bold magenta")
        table.add_column("#", style="dim", width=3); table.add_column("Name", style="bold green")
        table.add_column("Status", width=12); table.add_column("Sources", style="cyan"); table.add_column("Description", style="italic")
        for i, item in enumerate(results[:15]):
            status = "[blue]Installed[/blue]" if (item.get("installed") or item.get("is_installed")) else "[dim]Not Installed[/dim]"
            table.add_row(str(i+1), item['name'], status, ", ".join([v['source'] for v in item.get('variants', [])]),
                          (item.get('description', '')[:57] + "...") if len(item.get('description', '')) > 60 else item.get('description', ''))
        console.print(table); console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")

    def _output_installed_pretty(self, installed_list):
        if not installed_list: console.print(Panel("No installed applications found.", border_style="yellow")); return
        table = Table(title="Installed Applications", show_header=True, header_style="bold blue")
        table.add_column("Source", style="cyan"); table.add_column("Name", style="bold green")
        table.add_column("Version", style="dim"); table.add_column("Description", style="italic")
        for app in installed_list:
            table.add_row(app['primary_source'], app['name'], app.get('version', 'N/A'),
                          (app.get('description', '')[:50] + "...") if len(app.get('description', '')) > 50 else app.get('description', ''))
        console.print(table); console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")
