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
    """Murphy-proof decorator to isolate command failures and prevent backend crashes."""
    @wraps(func)
    async def wrapper(self, *args, **kwargs):
        json_mode = getattr(self, "json_mode", False)
        # Defensive Logging: Log the start of every command
        logging.debug(f"Command execution started: {func.__name__} (args={args}, kwargs={kwargs})")

        try:
            result = await func(self, *args, **kwargs)
            logging.debug(f"Command execution finished successfully: {func.__name__}")
            return result
        except asyncio.CancelledError:
            logging.warning(f"Command execution cancelled: {func.__name__}")
            # Re-raise to allow proper async cleanup but ensure we don't crash the event loop
            raise
        except Exception as e:
            import traceback
            err_trace = traceback.format_exc()
            error_msg = f"Murphy-proof Error in {func.__name__}: {str(e)}"
            logging.error(f"{error_msg}\n{err_trace}")

            if json_mode:
                # Ensure we don't pollute JSON output with partial data
                sys.stdout.write("\n")
                sys.stdout.write(json.dumps({
                    "status": "error",
                    "error": str(e),
                    "context": func.__name__,
                    "traceback": err_trace if self.config.get("logging.level") == "DEBUG" else None
                }, ensure_ascii=False) + "\n")
                sys.stdout.flush()
            else:
                try:
                    # Attempt graceful error handling
                    await self._handle_error(f"Command Error ({func.__name__})", e, json_mode)
                except:
                    # Final fail-safe: raw print to original stdout
                    hijacked_print(f"[ERROR] {error_msg}")
            return False
    return wrapper

class OmnistoreBackend:
    def __init__(self, json_mode: bool = False):
        self.config = ConfigManager()
        self.cache = CacheManager()
        self.env = EnvManager()
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
        self._ref_count = 0
        self._lock = asyncio.Lock()

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
        async with self._lock:
            session_replaced = False
            if self.session is None or self.session.closed:
                connector = aiohttp.TCPConnector(limit=100, ttl_dns_cache=300)
                self.session = aiohttp.ClientSession(
                    connector=connector,
                    timeout=aiohttp.ClientTimeout(total=60)
                )
                session_replaced = True

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
            if self._executor:
                try: self._executor.stop()
                except: pass
                self._executor = None

            if self.session and not self.session.closed:
                try: await asyncio.wait_for(self.session.close(), timeout=2.0)
                except: pass
                self.session = None

            if self._ai:
                try: await self._ai.close()
                except: pass

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
    async def run_search(self, query: str, json_mode: bool = False):
        # Murphy-proof: Input validation before resource acquisition
        valid_query = SecurityValidator.validate_string(query, "Search Query")
        async with self:
            if not self.manager: raise RuntimeError("SearchManager is not initialized.")
            results = await asyncio.wait_for(self.manager.search_all(valid_query), timeout=45)
            if results is None: results = []
            if json_mode: self._output_json(results)
            else: self._output_pretty(query, results)

    @safe_command
    async def run_install(self, name: str, source: str, url: Optional[str] = None, json_mode: bool = False) -> bool:
        # Murphy-proof: Guard against state corruption and malformed inputs
        SecurityValidator.validate_string(name, "Package Name")
        SecurityValidator.validate_string(source, "Source")
        if url: SecurityValidator.validate_url(url)

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
        SecurityValidator.validate_string(package_name, "Package Name")
        SecurityValidator.validate_string(source, "Source")
        SecurityValidator.validate_action_flag(flag)

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
    async def run_app_details(self, app_id: str, json_mode: bool = False):
        SecurityValidator.validate_string(app_id, "App ID")
        async with self:
            if not self.recommender or not self.manager: raise RuntimeError("Managers are not initialized.")
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
            async def _fetch_variant_info(variant):
                source = variant['source']
                if source in ("Native", "Pacman", "AUR"):
                    try:
                        binary = "pacman" if source in ("Native", "Pacman") else "yay"
                        if not shutil.which(binary): return
                        flag = "-Si" if source in ("Native", "Pacman") else "-Sii"
                        cmd = [binary, flag, variant.get('name', search_name)]
                        async with safe_subprocess(*cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL, env={**os.environ, "LC_ALL": "C"}) as proc:
                            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5)
                            if stdout:
                                info = stdout.decode()
                                if (m := re.search(r"(?:Depends On|Depends)\s+:\s+(.*)", info)): variant["depends"] = m.group(1).split()
                                if (m := re.search(r"Download Size\s+:\s+(.*)", info)): variant["download_size"] = m.group(1).strip()
                                if (m := re.search(r"Installed Size\s+:\s+(.*)", info)): variant["installed_size"] = m.group(1).strip()
                    except: pass
            variant_tasks = [_fetch_variant_info(v) for v in details.get("variants", [])]
            if variant_tasks: await asyncio.wait_for(asyncio.gather(*variant_tasks), timeout=20)
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
            async def scan_appimage():
                res = []
                try:
                    apps_dir = Path.home() / "Applications"
                    if apps_dir.exists():
                        loop = asyncio.get_running_loop()
                        files = await loop.run_in_executor(None, lambda: list(apps_dir.glob("*.AppImage")))
                        for f in files:
                            res.append({"name": f.stem, "primary_source": "AppImage", "variants": [{"source": "AppImage"}],
                                "installed": True, "description": f"Local AppImage at {f}", "version": "Local", "url": f.as_uri()})
                except Exception as e: logging.debug(f"scan_appimage error: {e}")
                return res
            async def scan_flatpak():
                res = []
                if shutil.which("flatpak") is None: return res
                try:
                    async with safe_subprocess("flatpak", "list", "--app", "--columns=name,application,version,description",
                                             stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
                        if stdout:
                            for line in stdout.decode().strip().splitlines():
                                parts = [p.strip() for p in line.split('\t')]
                                if len(parts) >= 2:
                                    res.append({"name": parts[0], "id": parts[1], "primary_source": "Flatpak", "variants": [{"source": "Flatpak"}],
                                        "installed": True, "version": parts[2] if len(parts) > 2 else "Unknown",
                                        "description": parts[3] if len(parts) > 3 else f"Flatpak app {parts[1]}"})
                except: pass
                return res
            async def scan_native():
                res = []
                if shutil.which("pacman") is None: return res
                try:
                    async with safe_subprocess("pacman", "-Qqne", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
                        if stdout:
                            for line in stdout.decode().strip().splitlines():
                                if line: res.append({"name": line, "primary_source": "Native", "variants": [{"source": "Native"}],
                                                       "installed": True, "description": "Native package", "version": "Local"})
                except: pass
                return res
            async def scan_aur():
                res = []
                if shutil.which("pacman") is None: return res
                try:
                    async with safe_subprocess("pacman", "-Qmq", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
                        if stdout:
                            for line in stdout.decode().strip().splitlines():
                                if line: res.append({"name": line, "primary_source": "AUR", "variants": [{"source": "AUR"}],
                                                       "installed": True, "description": "AUR package", "version": "Local"})
                except: pass
                return res
            results = await asyncio.gather(scan_appimage(), scan_flatpak(), scan_native(), scan_aur())
            for r in results: installed_list.extend(r)
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
            if json_mode: sys.stdout.write(json.dumps(installed_list) + "\n"); sys.stdout.flush()
            else: self._output_installed_pretty(installed_list)
            if self.cache: self.cache.save_installed_packages(installed_list)

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
    async def run_ai_explain(self, app_name: str, app_description: str = ""):
        SecurityValidator.validate_string(app_name, "App Name")
        res = await self.ai.explain_app(app_name, app_description)
        sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()

    @safe_command
    async def run_ai_recommend(self, prompt: str):
        SecurityValidator.validate_string(prompt, "AI Prompt")
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
        else: sys.stdout.write(json.dumps({"response": "pacman not found, conflict check skipped."}) + "\n")
        sys.stdout.flush()

    @safe_command
    async def run_ai_correct(self, query: str):
        SecurityValidator.validate_string(query, "Query")
        res = await self.ai.suggest_correction(query)
        sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n"); sys.stdout.flush()

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
            else: sys.stdout.write(json.dumps({"response": "Search manager not initialized."}) + "\n")
        sys.stdout.flush()

    @safe_command
    async def run_ai_health(self):
        """Murphy-proof: Unified AI health report logic."""
        sys.stdout.flush()
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
        SecurityValidator.validate_path(filepath, "Import Path")
        res = self.essentials.import_from_file(filepath)
        sys.stdout.write(json.dumps(res, ensure_ascii=False) + "\n"); sys.stdout.flush()

    @safe_command
    async def run_export_packages(self, filepath: str):
        SecurityValidator.validate_path(filepath, "Export Path")
        installed = []
        commands = [ (["pacman", "-Qqne"], "Native"), (["flatpak", "list", "--app", "--columns=application"], "Flatpak"), (["yay", "-Qm"], "AUR") ]
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
    async def run_clean_system(self, json_mode: bool = False) -> bool:
        async def cb(m): await self._flutter_callback(m, json_mode)
        try:
            if not json_mode: console.print(Panel("Starting System Cleanup", border_style="blue"))
            if shutil.which("pacman") is None: await cb("[INFO] pacman not found, skipping."); return True
            await cb("[INFO] Detecting orphan packages...")
            try:
                async with safe_subprocess("pacman", "-Qtdq", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE) as proc:
                    stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
                    orphans = [o.strip() for o in stdout.decode().strip().splitlines() if o.strip()]
            except: orphans = []
            if orphans:
                await cb(f"[INFO] Cleaning {len(orphans)} orphans...");
                if not await self.executor._ensure_privileged(cb): return False
                async with safe_subprocess("sudo", "pacman", "-Rs", "--noconfirm", *orphans) as p:
                    try: await asyncio.wait_for(p.wait(), timeout=60)
                    except asyncio.TimeoutError: pass
            await cb("[INFO] Cleaning package cache...")
            if await self.executor._ensure_privileged(cb):
                async with safe_subprocess("sudo", "pacman", "-Scc", stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT) as p:
                    try:
                        p.stdin.write(b"y\ny\n"); await p.stdin.drain(); p.stdin.close()
                        while True:
                            line_bytes = await p.stdout.readline()
                            if not line_bytes: break
                            line = line_bytes.decode('utf-8', errors='ignore').strip()
                            if line: await cb(f"[INFO] {line}")
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

    async def _handle_error(self, context: str, exception: Exception, json_mode: bool):
        error_msg = f"{context}: {str(exception)}"
        if json_mode: sys.stdout.write(json.dumps({"status": "error", "error": error_msg, "results": [], "response": f"Error: {error_msg}"}) + "\n")
        else: logging.error(error_msg)
        sys.stdout.flush()

    def _output_json(self, results):
        def serialize_item(item):
            return { "name": str(item.get("name", "Unknown")), "description": str(item.get("description", "")),
                "installed": bool(item.get("installed", False) or item.get("is_installed", False)),
                "primary_source": str(item.get("primary_source") or item.get("source") or "Native"),
                "url": str(item.get("url") or ""), "variants": item.get("variants", []),
                "version": str(item.get("last_version") or item.get("version") or "N/A"), "score": int(item.get("score", 0)),
                "icon": item.get("icon"), "is_exact_match": item.get("is_exact_match", False), "screenshots": item.get("screenshots", []), }
        output = [serialize_item(i) for i in results]
        sys.stdout.write(json.dumps(output, ensure_ascii=False) + "\n"); sys.stdout.flush()

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
