import asyncio
import json
import logging
import sys
import os
import re
import shutil
import inspect
import contextvars
import time
from functools import wraps
from pathlib import Path
from typing import Optional, List, Dict, Any, Union, Set
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

# Force all print statements to flush immediately and support redirection
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

class ResourceCoordinator:
    """
    Murphy-proof: Centralized resource tracker for absolute lifecycle management.
    Ensures that every file, task, and socket is explicitly tracked and reaped.
    """
    def __init__(self):
        self._tasks: Set[asyncio.Task] = set()
        self._files: Set[Union[str, Path]] = set()
        self._handles: List[Any] = []
        self._lock = asyncio.Lock()

    def track_task(self, task: asyncio.Task):
        self._tasks.add(task)
        task.add_done_callback(self._tasks.discard)

    def track_file(self, path: Union[str, Path]):
        self._files.add(path)

    def track_handle(self, handle: Any):
        self._handles.append(handle)

    async def cleanup(self):
        """Absolute reaping of all tracked resources."""
        async with self._lock:
            if self._tasks:
                logging.debug(f"ResourceCoordinator: Cancelling {len(self._tasks)} tasks.")
                for task in list(self._tasks):
                    if not task.done(): task.cancel()
                await asyncio.gather(*self._tasks, return_exceptions=True)
                self._tasks.clear()

            for handle in self._handles:
                try:
                    if hasattr(handle, "close"):
                        res = handle.close()
                        if inspect.isawaitable(res): await res
                except: pass
            self._handles.clear()

            for path in self._files:
                try:
                    if os.path.exists(path):
                        if os.path.isdir(path): shutil.rmtree(path)
                        else: os.remove(path)
                except: pass
            self._files.clear()

def safe_command(func):
    """
    Murphy-proof decorator with Panic Recovery, Mandatory Resource Tracking,
    and State Locking to prevent concurrent duplicate commands.
    """
    @wraps(func)
    async def wrapper(self: 'OmnistoreBackend', *args, **kwargs):
        json_mode = getattr(self, "json_mode", False)

        # 1. State Locking: Reject concurrent duplicate high-frequency commands
        is_action = func.__name__ in ("run_install", "run_uninstall", "run_update", "run_clean_system")
        if is_action:
            for active_id in self._active_commands:
                if active_id.startswith(func.__name__):
                    error_msg = f"State Lock: A duplicate task '{func.__name__}' is already running."
                    logging.warning(error_msg)
                    if json_mode:
                        self._output_command_response(CommandResponse(status="error", error="StateConflict", message=error_msg))
                    return False

        # 2. Timeout Calculation
        is_long_running = is_action or func.__name__ in ("run_bootstrap", "run_import_packages", "run_export_packages")
        timeout = kwargs.pop("_timeout", 3600 if is_long_running else 120)

        # 3. Execution & Panic Recovery
        command_id = f"{func.__name__}_{time.time()}"
        self._active_commands[command_id] = asyncio.current_task()

        try:
            result = await asyncio.wait_for(func(self, *args, **kwargs), timeout=timeout)
            return result
        except asyncio.TimeoutError:
            error_msg = f"Murphy-proof: Command {func.__name__} timed out after {timeout}s"
            logging.error(error_msg)
            if json_mode:
                self._output_command_response(CommandResponse(status="error", error="TimeoutError", message=error_msg, context=func.__name__))
            return False
        except asyncio.CancelledError:
            logging.warning(f"Murphy-proof: Command {func.__name__} was cancelled.")
            if json_mode:
                self._output_command_response(CommandResponse(status="error", error="CancelledError", message=f"Command {func.__name__} was cancelled.", context=func.__name__))
            raise
        except BaseException as e:
            # Murphy-proof: Catching BaseException ensures we don't swallow
            # critical signals (like SIGTERM/KeyboardInterrupt) while still
            # providing structured error feedback before re-raising if necessary.
            import traceback
            err_trace = traceback.format_exc()
            error_msg = f"Panic Recovery Triggered in {func.__name__}: {str(e)}"
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
                    # We pass the error to handle_error, but we must be careful with BaseException
                    if isinstance(e, Exception):
                        await self._handle_error(f"Command Error ({func.__name__})", e, json_mode)
                    else:
                        hijacked_print(f"[CRITICAL] {error_msg}")
                except Exception as inner_e:
                    logging.error(f"Double fault in _handle_error: {inner_e}")
                    hijacked_print(f"[ERROR] {error_msg}")

            # If it's a critical BaseException (not standard Exception), re-raise it
            if not isinstance(e, Exception):
                raise
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
        self._resources = ResourceCoordinator()
        self._updater = None
        self._executor = None
        self._ai = None
        self._repo_manager = None
        self._essentials = None
        self.json_mode = json_mode
        self.session: Optional[aiohttp.ClientSession] = None
        self._ref_count = 0
        self._lock = asyncio.Lock()
        self._active_commands: Dict[str, asyncio.Task] = {}

    def create_task(self, coro) -> asyncio.Task:
        task = asyncio.create_task(coro)
        self._resources.track_task(task)
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
            self._resources.track_handle(self._ai)
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
        async with self._lock:
            try:
                if self.session is None or self.session.closed:
                    connector = aiohttp.TCPConnector(limit=100, ttl_dns_cache=300, use_dns_cache=True, enable_cleanup_closed=True)
                    self.session = aiohttp.ClientSession(connector=connector, timeout=aiohttp.ClientTimeout(total=60, connect=10))
                    self._resources.track_handle(self.session)
            except Exception as e: logging.error(f"Murphy-proof: Critical Session failure: {e}")

            try:
                if self.recommender is None: self.recommender = RecommendationManager(self.session, self.habit_tracker, backend=self)
            except Exception as e: logging.error(f"Circuit Breaker: RecommendationManager failed: {e}")

            try:
                if self.manager is None: self.manager = SearchManager(self.config, self.session, self.habit_tracker, recommender=self.recommender, cache_manager=self.cache, ai_assistant=self.ai)
            except Exception as e: logging.error(f"Circuit Breaker: SearchManager failed: {e}")
        return self

    async def __aenter__(self):
        await self.initialize()
        async with self._lock: self._ref_count += 1
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        async with self._lock:
            if self._ref_count > 0: self._ref_count -= 1
            if self._ref_count > 0: return
            try:
                if self._executor:
                    try: self._executor.stop()
                    except: pass
                await self._resources.cleanup()
                self.session = self.manager = self.recommender = self._ai = self._updater = self._executor = self._repo_manager = self._essentials = None
            except BaseException as e:
                if isinstance(e, Exception):
                    logging.error(f"Murphy-proof Critical Cleanup Failure: {e}")
                else:
                    raise

    async def _flutter_callback(self, msg: str, json_mode: bool = False, level: Optional[str] = None):
        if level is None:
            if msg.startswith(("[ERROR]", "[Error]")): level = "ERROR"
            elif msg.startswith("[PROGRESS]"): level = "PROGRESS"
            else: level = "INFO"
        clean_msg = msg
        for prefix in ["[Status]", "[INFO]", "[ERROR]", "[Error]", "[DEBUG]", "[Executor]"]:
            if clean_msg.startswith(prefix): clean_msg = clean_msg.replace(prefix, "", 1).strip(); break
        if json_mode:
            icon = {"ERROR": "❌", "SUCCESS": "✅", "INFO": "🔹", "PROGRESS": "⏳"}.get(level, "🔹")
            try:
                output = json.dumps({"type": "log", "message": f"[{level.upper()}] {icon} {clean_msg}", "level": level.upper()}, ensure_ascii=False)
                sys.stdout.write(f"[CALLBACK] {output}\n"); sys.stdout.flush()
            except: pass
        else: logging.info(f"{level}: {clean_msg}")

    @safe_command
    async def run_search(self, query: str, json_mode: bool = False) -> Any:
        valid_query = SecurityValidator.validate_string(query, "Search Query")
        async with self:
            if not self.manager: raise RuntimeError("SearchManager offline")
            results = await asyncio.wait_for(self.manager.search_all(valid_query), timeout=45)
            typed_results = self._to_app_packages(results or [])
            if json_mode: self._output_command_response(CommandResponse(status="success", response=[item.model_dump(exclude_none=True) for item in typed_results], context="run_search"))
            else: self._output_pretty(query, [item.model_dump() for item in typed_results])
            return typed_results

    @safe_command
    async def run_install(self, name: str, source: str, url: Optional[str] = None, json_mode: bool = False) -> Any:
        v_name = SecurityValidator.validate_string(name, "Package Name")
        v_source = SecurityValidator.validate_string(source, "Source")
        v_url = SecurityValidator.validate_url(url) if url else None
        async with self:
            async def cb(m): await self._flutter_callback(m, json_mode)
            if not json_mode: console.print(Panel(f"Installing [bold green]{v_name}[/bold green] from [cyan]{v_source}[/cyan]", border_style="green"))
            success = await self.executor.install({"name": v_name, "id": v_name, "source": v_source, "url": v_url}, callback=cb)
            if success:
                self.cache.invalidate_installed_cache()
                if not json_mode: console.print(Panel(f"Successfully installed [bold green]{v_name}[/bold green]! 🎉", border_style="green"))
            if json_mode: self._output_command_response(CommandResponse(status="success" if success else "error", response=success))
            return success

    @safe_command
    async def run_uninstall(self, package_name: str, source: str, json_mode: bool = False, flag: str = "-R") -> Any:
        v_name = SecurityValidator.validate_string(package_name, "Package Name")
        v_source = SecurityValidator.validate_string(source, "Source")
        v_flag = SecurityValidator.validate_action_flag(flag)
        async with self:
            async def cb(m): await self._flutter_callback(m, json_mode)
            if not json_mode: console.print(Panel(f"Uninstalling [bold red]{v_name}[/bold red] from [cyan]{v_source}[/cyan]", border_style="red"))
            success = await self.executor.uninstall({"name": v_name, "id": v_name, "source": v_source, "flag": v_flag}, callback=cb)
            if success:
                self.cache.invalidate_installed_cache()
                if not json_mode: console.print(Panel(f"Successfully uninstalled [bold red]{v_name}[/bold red]! ✨", border_style="green"))
            if json_mode: self._output_command_response(CommandResponse(status="success" if success else "error", response=success))
            return success

    @safe_command
    async def run_update(self, package_name: str, source: str, json_mode: bool = False) -> Any:
        v_name = SecurityValidator.validate_string(package_name, "Package Name")
        v_source = SecurityValidator.validate_string(source, "Source")
        async with self:
            async def cb(m): await self._flutter_callback(m, json_mode)
            if not json_mode: console.print(Panel(f"Updating [bold blue]{v_name}[/bold blue] via [cyan]{v_source}[/cyan]", border_style="blue"))
            success = await self.executor.update({"name": v_name, "id": v_name, "source": v_source}, callback=cb)
            if success:
                self.cache.invalidate_installed_cache()
                if not json_mode: console.print(Panel(f"Update completed! 🎉", border_style="green"))
            if json_mode: self._output_command_response(CommandResponse(status="success" if success else "error", response=success))
            return success

    @safe_command
    async def run_check_updates(self, json_mode: bool = False):
        updates = await self.updater.check_all_updates()
        if json_mode: sys.stdout.write(json.dumps(updates, ensure_ascii=False) + "\n"); sys.stdout.flush()
        else:
            if not updates: console.print(Panel("All apps are up to date! ✨", border_style="green"))
            else:
                table = Table(title="Available Updates"); table.add_column("Source"); table.add_column("Package Name"); table.add_column("New Version")
                for u in updates: table.add_row(u['source'], u['name'], u['new_version'])
                console.print(table)
        return updates

    @safe_command
    async def run_recommendations(self, json_mode: bool = False):
        async with self:
            if not self.recommender: raise RuntimeError("RecommendationManager offline")
            sources = list(self.manager.sources.values()) if self.manager else []
            results = await self.recommender.get_recommendations(sources=sources)
            if json_mode: sys.stdout.write(json.dumps(results, ensure_ascii=False) + "\n"); sys.stdout.flush()
            return results

    @safe_command
    async def run_app_details(self, app_id: str, json_mode: bool = False, source: Optional[str] = None) -> Any:
        v_id = SecurityValidator.validate_strict_id(app_id, "App ID")
        async with self:
            if not self.recommender: raise RuntimeError("Backend offline")
            details = await asyncio.wait_for(self.recommender.get_details(v_id), timeout=30)
            if sys.platform.startswith("linux") and shutil.which("pacman"):
                for variant in details.get("variants", []):
                    if variant.get('source') in ("Native", "Pacman", "AUR"):
                        try:
                            binary = "pacman" if variant['source'] != "AUR" else "yay"
                            if not shutil.which(binary): continue
                            pkg_name = variant.get('name') or details.get('name')
                            async with safe_subprocess(binary, "-Si", pkg_name, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5)
                                if stdout:
                                    info = stdout.decode()
                                    if (m := re.search(r"Download Size\s+:\s+(.*)", info)): variant["download_size"] = m.group(1).strip()
                                    if (m := re.search(r"Installed Size\s+:\s+(.*)", info)): variant["installed_size"] = m.group(1).strip()
                        except: pass
            typed_details = AppPackage(**details)
            if json_mode: self._output_command_response(CommandResponse(status="success", response=typed_details.model_dump(exclude_none=True), context="run_app_details"))
            return typed_details

    @safe_command
    async def run_list_installed(self, json_mode: bool = False, force_refresh: bool = False, include_unmanaged: bool = True) -> Any:
        if not force_refresh:
            cached = self.cache.get_installed_packages()
            if cached:
                if json_mode: self._output_command_response(CommandResponse(status="success", response=cached, context="run_list_installed"))
                return cached
        async with self:
            sources = list(self.manager.sources.values()) if self.manager else []
            results = await asyncio.gather(*[s.list_installed() for s in sources if s.capabilities.get("list_installed")], return_exceptions=True)
            installed = []
            for r in results:
                if isinstance(r, list): installed.extend(r)
            if include_unmanaged and sys.platform == "win32": installed.extend(await scan_windows_unmanaged_installed(self.manager))
            merged = self._merge_installed_apps(installed)
            typed = [item.model_dump(exclude_none=True) for item in self._to_app_packages(merged)]
            if json_mode: self._output_command_response(CommandResponse(status="success", response=typed, context="run_list_installed"))
            self.cache.save_installed_packages(typed)
            return typed

    @safe_command
    async def run_list_installed_sources(self, json_mode: bool = False, force_refresh: bool = False, include_unmanaged: bool = True):
        return await self.run_list_installed(json_mode, force_refresh, include_unmanaged)

    @safe_command
    async def run_list_plugins(self, json_mode: bool = False):
        async with self:
            registry = self.manager.plugin_registry if self.manager else None
            plugins = registry.list_plugins() if registry else []
            if json_mode: sys.stdout.write(json.dumps(plugins, ensure_ascii=False) + "\n"); sys.stdout.flush()
            else:
                table = Table(title="OmniStore Plugins"); table.add_column("ID"); table.add_column("Name"); table.add_column("Enabled")
                for p in plugins: table.add_row(p["id"], p["name"], str(p["enabled"]))
                console.print(table)
            return plugins

    @safe_command
    async def run_set_plugin_enabled(self, plugin_id: str, enabled: bool, json_mode: bool = False) -> bool:
        SecurityValidator.validate_string(plugin_id, "Plugin ID")
        async with self:
            ok = bool(self.manager and self.manager.plugin_registry and self.manager.plugin_registry.enable(plugin_id, enabled))
            self.cache.invalidate_installed_cache()
            if json_mode: sys.stdout.write(json.dumps({"status": "success" if ok else "error", "plugin_id": plugin_id, "enabled": enabled}) + "\n"); sys.stdout.flush()
            return ok

    @safe_command
    async def run_remove_plugin(self, plugin_id: str, json_mode: bool = False) -> bool:
        SecurityValidator.validate_string(plugin_id, "Plugin ID")
        async with self:
            ok = bool(self.manager and self.manager.plugin_registry and self.manager.plugin_registry.remove(plugin_id))
            self.cache.invalidate_installed_cache()
            if json_mode: sys.stdout.write(json.dumps({"status": "success" if ok else "error", "plugin_id": plugin_id}) + "\n"); sys.stdout.flush()
            return ok

    def _merge_installed_apps(self, apps: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        merged: Dict[str, Dict[str, Any]] = {}
        for app in apps:
            if not isinstance(app, dict): continue
            name = str(app.get("name") or app.get("id") or "").lower().strip()
            if not name: continue
            if name not in merged:
                merged[name] = app.copy()
                if 'variants' not in merged[name]: merged[name]['variants'] = []
                continue
            target = merged[name]
            existing_variants = target.get('variants', [])
            for variant in app.get('variants', []):
                if variant not in existing_variants: existing_variants.append(variant)
            target['variants'] = existing_variants
            for field in ('description', 'version', 'developer', 'icon', 'install_location', 'managed'):
                if not target.get(field) and app.get(field): target[field] = app[field]
        return sorted(merged.values(), key=lambda x: x.get("name", "").lower())

    @safe_command
    async def run_list_custom_repos(self):
        flatpaks = await self.repo_manager.list_flatpak_remotes()
        pacmans = await self.repo_manager.list_pacman_repos()
        appimages = self.repo_manager.list_appimage_feeds()
        result = {"flatpak": flatpaks, "pacman": pacmans, "appimage": [{"name": Path(url).stem, "url": url} for url in appimages]}
        sys.stdout.write(json.dumps(result, ensure_ascii=False) + "\n"); sys.stdout.flush()
        return result

    @safe_command
    async def run_add_custom_repo(self, repo_type: str, name: str, url: str, json_mode: bool = False) -> bool:
        SecurityValidator.validate_string(repo_type, "Repo Type"); SecurityValidator.validate_string(name, "Repo Name"); SecurityValidator.validate_url(url)
        async with self:
            async def cb(m): await self._flutter_callback(m, json_mode)
            success = False
            if repo_type == "flatpak": success = await self.repo_manager.add_flatpak_remote(name, url, callback=cb)
            elif repo_type == "pacman": success = await self.repo_manager.add_pacman_repo(name, url, callback=cb)
            elif repo_type == "appimage": success = self.repo_manager.add_appimage_feed(url)
            if json_mode: sys.stdout.write(json.dumps({"status": "success" if success else "error"}) + "\n"); sys.stdout.flush()
            return success

    @safe_command
    async def run_remove_custom_repo(self, repo_type: str, name: str, json_mode: bool = False) -> bool:
        SecurityValidator.validate_string(repo_type, "Repo Type"); SecurityValidator.validate_string(name, "Repo Name")
        async with self:
            async def cb(m): await self._flutter_callback(m, json_mode)
            success = False
            if repo_type == "flatpak": success = await self.repo_manager.remove_flatpak_remote(name, callback=cb)
            elif repo_type == "pacman": success = await self.repo_manager.remove_pacman_repo(name, callback=cb)
            elif repo_type == "appimage": success = self.repo_manager.remove_appimage_feed(name)
            if json_mode: sys.stdout.write(json.dumps({"status": "success" if success else "error"}) + "\n"); sys.stdout.flush()
            return success

    @safe_command
    async def run_ai_explain(self, app_name: str, app_description: str = "", json_mode: bool = False):
        v_name = SecurityValidator.validate_string(app_name, "App Name")
        async with self:
            res = await self.ai.explain_app(v_name, str(app_description)[:10000])
            if json_mode: self._output_command_response(CommandResponse(status="success", response=res, context="ai_explain"))
            else: hijacked_print(res)
            return res

    @safe_command
    async def run_ai_recommend(self, prompt: str, json_mode: bool = False):
        v_prompt = SecurityValidator.validate_string(prompt, "AI Prompt")
        async with self:
            candidates = await self.manager.search_all(v_prompt.split()[0]) if self.manager else []
            res = await self.ai.recommend_apps(v_prompt, candidates)
            if json_mode: self._output_command_response(CommandResponse(status="success", response=res, context="ai_recommend"))
            else: hijacked_print(res)
            return res

    @safe_command
    async def run_ai_analyze_error(self, error_log: str, json_mode: bool = False):
        async with self:
            res = await self.ai.analyze_error(str(error_log)[:50000])
            if json_mode: self._output_command_response(CommandResponse(status="success", response=res, context="ai_analyze_error"))
            else: hijacked_print(res)
            return res

    @safe_command
    async def run_ai_changelog(self, name: str, current: str, next_v: str, json_mode: bool = False):
        async with self:
            res = await self.ai.summarize_changelog(name, current, next_v)
            if json_mode: self._output_command_response(CommandResponse(status="success", response=res, context="ai_changelog"))
            else: hijacked_print(res)
            return res

    @safe_command
    async def run_ai_cli(self, name: str, summary: str, json_mode: bool = False):
        async with self:
            res = await self.ai.generate_cli_command(name, summary)
            if json_mode: self._output_command_response(CommandResponse(status="success", response=res, context="ai_cli"))
            else: hijacked_print(res)
            return res

    @safe_command
    async def run_ai_conflicts(self, name: str, json_mode: bool = False):
        async with self:
            packages = []
            if shutil.which("pacman"):
                async with safe_subprocess("pacman", "-Qq", stdout=asyncio.subprocess.PIPE) as proc:
                    stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5)
                    packages = stdout.decode().splitlines()
            res = await self.ai.detect_conflicts(name, packages)
            if json_mode: self._output_command_response(CommandResponse(status="success", response=res, context="ai_conflicts"))
            else: hijacked_print(res)
            return res

    @safe_command
    async def run_ai_correct(self, query: str, json_mode: bool = False):
        async with self:
            res = await self.ai.suggest_correction(query)
            if json_mode: self._output_command_response(CommandResponse(status="success", response=res, context="ai_correct"))
            else: hijacked_print(res)
            return res

    @safe_command
    async def run_ai_compare(self, name: str, json_mode: bool = False):
        async with self:
            candidates = await self.manager.search_all(name) if self.manager else []
            res = await self.ai.compare_variants(name, candidates[0].get('variants', []) if candidates else [])
            if json_mode: self._output_command_response(CommandResponse(status="success", response=res, context="ai_compare"))
            else: hijacked_print(res)
            return res

    @safe_command
    async def run_ai_health(self, json_mode: bool = False):
        async with self:
            status = await self.env.check_env()
            res = await self.ai.generate_health_report(status)
            if json_mode: self._output_command_response(CommandResponse(status="success", response=res, context="ai_health"))
            else: hijacked_print(res)
            return res

    @safe_command
    async def run_get_essentials(self):
        res = self.essentials.get_essentials()
        sys.stdout.write(json.dumps(res, ensure_ascii=False) + "\n"); sys.stdout.flush()
        return res

    @safe_command
    async def run_import_packages(self, filepath: str):
        SecurityValidator.validate_path(filepath)
        res = self.essentials.import_from_file(filepath)
        sys.stdout.write(json.dumps(res, ensure_ascii=False) + "\n"); sys.stdout.flush()
        return res

    @safe_command
    async def run_export_packages(self, filepath: str):
        """Murphy-proof export with non-blocking I/O."""
        SecurityValidator.validate_path(filepath)
        async with self:
            installed = await self.run_list_installed()
            def _write():
                with open(filepath, 'w', encoding='utf-8') as f: json.dump(installed, f, ensure_ascii=False)
            await asyncio.to_thread(_write)
            if self.json_mode: sys.stdout.write(json.dumps({"status": "success", "count": len(installed)}) + "\n"); sys.stdout.flush()
        return True

    @safe_command
    async def run_launch(self, name: str, source: str, json_mode: bool = False) -> bool:
        async with self:
            src = source.lower()
            if self.manager and src in self.manager.sources:
                success = await self.manager.sources[src].launch({"name": name, "id": name})
                if json_mode: sys.stdout.write(json.dumps({"status": "success" if success else "error"}) + "\n")
                return success
            return False

    @safe_command
    async def run_locate(self, name: str, source: str, json_mode: bool = False) -> bool:
        async with self:
            src = source.lower()
            if self.manager and src in self.manager.sources:
                success = await self.manager.sources[src].locate({"name": name, "id": name})
                if json_mode: sys.stdout.write(json.dumps({"status": "success" if success else "error"}) + "\n")
                return success
            return False

    @safe_command
    async def run_get_storage_info(self, json_mode: bool = False):
        async with self:
            total, used, free = shutil.disk_usage(os.path.expanduser("~"))
            info = {"disk_total": total, "disk_used": used, "disk_free": free}
            if json_mode: sys.stdout.write(json.dumps(info) + "\n"); sys.stdout.flush()
            return info

    @safe_command
    async def run_ai_summary(self, json_mode: bool = False):
        res = await self.ai.summarize_project()
        if json_mode: sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()
        return res

    @safe_command
    async def run_save_config(self, config_data: dict): return self.config.save(config_data)

    @safe_command
    async def run_update_env(self, env_vars: dict, json_mode: bool = False):
        for k, v in env_vars.items():
            if v is not None: os.environ[k] = str(v)
            elif k in os.environ: del os.environ[k]
        if json_mode: sys.stdout.write(json.dumps({"status": "success"}) + "\n"); sys.stdout.flush()
        return True

    @safe_command
    async def run_ai_test(self, json_mode: bool = False):
        res = await self.ai.test_connection()
        if json_mode: sys.stdout.write(json.dumps({"status": "success" if res == "success" else "error", "response": res}) + "\n"); sys.stdout.flush()
        return res

    @safe_command
    async def run_ai_pick(self, json_mode: bool = False):
        async with self:
            recs = await self.recommender.get_recommendations() if self.recommender else {}
            res = await self.ai.pick_of_the_day(recs.get('trending', [])[:10])
            sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()
            return res

    @safe_command
    async def run_clean_system(self, json_mode: bool = False) -> Any:
        if not sys.platform.startswith("linux"): return True
        async with self:
            async def cb(m): await self._flutter_callback(m, json_mode)
            if shutil.which("pacman"):
                await cb("[INFO] Detecting orphan packages...")
                orphans = []
                try:
                    async with safe_subprocess("pacman", "-Qtdq", stdout=asyncio.subprocess.PIPE) as proc:
                        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
                        orphans = [o.strip() for o in stdout.decode().splitlines() if o.strip()]
                except: pass
                if orphans and await self.executor._ensure_privileged(cb):
                    await cb(f"[INFO] Removing {len(orphans)} orphan packages...")
                    async with safe_subprocess("sudo", "pacman", "-Rns", "--noconfirm", *orphans) as p: await asyncio.wait_for(p.wait(), timeout=120)
                await cb("[INFO] Cleaning package cache...")
                if await self.executor._ensure_privileged(cb):
                    async with safe_subprocess("sudo", "pacman", "-Scc", "--noconfirm") as p: await asyncio.wait_for(p.wait(), timeout=120)
            return True

    def _output_command_response(self, resp: CommandResponse):
        try: sys.stdout.write("\n" + resp.model_dump_json(exclude_none=True) + "\n"); sys.stdout.flush()
        except: pass

    def _to_app_packages(self, results: List[Dict]) -> List[AppPackage]:
        output = []
        for item in results:
            try:
                if 'id' not in item and 'name' in item: item['id'] = item['name']
                output.append(AppPackage(**item))
            except Exception as e: logging.error(f"Murphy-proof: Validation failed for AppPackage '{item.get('name', 'Unknown')}': {e}")
        return output

    def _output_pretty(self, query, results):
        if not results: console.print(Panel(f"No results found for '{query}'", border_style="yellow")); return
        table = Table(title=f"Search Results: {query}"); table.add_column("Name", style="bold green"); table.add_column("Source", style="cyan")
        for item in results[:15]: table.add_row(item['name'], item.get('primary_source', 'Native'))
        console.print(table)
