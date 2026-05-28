import functools
import json
import sys
import argparse
import aiohttp
import logging
import asyncio
import os
import re
from pathlib import Path
from typing import Optional
from rich.console import Console
from rich.logging import RichHandler
from rich.panel import Panel
from rich.table import Table
from core.friendly_messages import get_friendly_message

# Initial rich console
console = Console(force_terminal=True)

# Force all print statements to flush immediately, ensuring real-time output to Flutter.
# In JSON mode we must allow real JSON payloads to pass through while still filtering
# non-JSON chatter that would break the frontend parser.
_orig_print = print


def print(*args, **kwargs):
    msg = " ".join(map(str, args))

    if msg.startswith("[CALLBACK]") or msg.startswith("[PROGRESS]") or msg.startswith("[SPEED]"):
        _orig_print(*args, **kwargs, flush=True)
        return

    json_mode = getattr(main, "json_mode_active", False)
    if json_mode:
        # Only allow actual JSON payloads in JSON mode.
        if msg.startswith("{") or msg.startswith("[") or msg.startswith('"') or msg.startswith("true") or msg.startswith("false") or msg.startswith("null"):
            _orig_print(*args, **kwargs, flush=True)
        return

    _orig_print(*args, **kwargs, flush=True)

# Path handling optimization
current_file_path = Path(__file__).resolve()
sys.path.insert(0, str(current_file_path.parent))
BASE_DIR = Path(__file__).resolve().parent
sys.path.append(str(BASE_DIR))

# Enhanced logging config
def setup_logging(level="INFO", json_mode=False):
    if json_mode:
        logging.basicConfig(
            level=getattr(logging, level.upper(), logging.INFO),
            format="%(message)s",
            handlers=[logging.StreamHandler(sys.stderr)]
        )
    else:
        logging.basicConfig(
            level=getattr(logging, level.upper(), logging.INFO),
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

from core.downloader.downloader import InstallExecutor
from core.search.searchmanager import SearchManager
from core.recommendation_manager import RecommendationManager
from core.config_loader import ConfigManager
from core.cache_manager import CacheManager
from core.env_manager import EnvManager
from core.update_manager import UpdateManager
from core.ai.assistant import AIAssistant
from core.search.custom_repo import CustomRepoManager
from core.essentials_manager import EssentialsManager


class OmnistoreBackend:
    def __init__(self, json_mode=False):
        self.config = ConfigManager()
        self.cache = CacheManager()
        self.env = EnvManager()
        self.manager: SearchManager | None = None
        self.recommender: RecommendationManager | None = None
        self.updater = UpdateManager(self.config)
        self.executor = InstallExecutor()
        self.is_action = False
        self.json_mode = json_mode
        
        # Initialize new features
        self.ai = AIAssistant(self.config)
        self.repo_manager = CustomRepoManager(self.config)
        self.essentials = EssentialsManager(self.config)

        setup_logging(self.config.get("logging.level", "INFO"), json_mode)

    async def initialize(self, session: aiohttp.ClientSession):
        self.manager = SearchManager(self.config, session)
        self.recommender = RecommendationManager(session)
        if self.manager is None:
            raise RuntimeError(
                "Failed to initialize SearchManager. Check configuration and environment.")

    # --- Unified Callback Handling ---
    async def _flutter_callback(self, msg: str, json_mode: bool = False, level: Optional[str] = None):
        """Unified log exit with level support and auto-detection"""
        if level is None:
            if msg.startswith("[ERROR]") or msg.startswith("[Error]"): level = "ERROR"
            elif msg.startswith("[INFO]") or msg.startswith("[Status]") or msg.startswith("[Executor]"): level = "INFO"
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
            # For terminal output in UI, we can add some box-like decoration if it's a major event
            # but keep it simple JSON for the protocol.
            # The "beautification" in UI will be handled by the Log viewer's colors,
            # but we can add some Unicode characters to make it "体贴宜人".
            icon = "📦"
            if level == "ERROR": icon = "❌"
            elif level == "SUCCESS": icon = "✅"
            elif level == "INFO": icon = "🔹"
            elif level == "PROGRESS": icon = "⏳"

            decorated_msg = f"{icon} {clean_msg}"

            output = json.dumps(
                {"type": "log", "message": f"[{level.upper()}] {decorated_msg}", "level": level.upper()}, ensure_ascii=False)
            sys.stdout.write(f"[CALLBACK] {output}\n")
            sys.stdout.flush()
        else:
            if level == "ERROR":
                logging.error(clean_msg)
            elif level == "PROGRESS":
                # Progress is usually handled specifically, but for terminal we can just info it
                if not clean_msg.isdigit(): # If it's just a number, maybe skip or format
                     logging.info(f"Progress: {clean_msg}%")
            else:
                logging.info(clean_msg)

    async def run_search(self, query: str, json_mode: bool = False):
        try:
            timeout = aiohttp.ClientTimeout(total=30)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                await self.initialize(session)
                results = await self.manager.search_all(query)  # type: ignore

                if not self.manager:
                    raise RuntimeError("SearchManager is not initialized.")

                if results is None:
                    results = []

                if json_mode:
                    self._output_json(results)
                else:
                    self._output_pretty(query, results)

        except Exception as e:
            error_msg = f"Backend Error: {str(e)}"
            if json_mode:
                print(json.dumps({"error": error_msg, "results": []}))
            else:
                print(f"[Error] {error_msg}")

    async def run_install(self, name: str, source: str, url: Optional[str] = None, json_mode: bool = False):
        """Installation logic"""
        self.is_action = True
        package_data = {"name": name, "source": source, "url": url}

        if self.manager and self.manager.habit_tracker:
            self.manager.habit_tracker.record_install(name, source)

        async def cb(m):
            await self._flutter_callback(m, json_mode)

        if not json_mode:
            console.print(Panel(f"Installing [bold green]{name}[/bold green] from [cyan]{source}[/cyan]", border_style="green"))

        success = await self.executor.install(package_data, callback=cb)
        if success:
            self.cache.invalidate_installed_cache()
            if not json_mode:
                console.print(Panel(f"Successfully installed [bold green]{name}[/bold green]! 🎉", border_style="green"))
                console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")

    async def run_uninstall(self, package_name: str, source: str, json_mode: bool = False, flag: str = "-R"):
        """Uninstallation logic"""
        self.is_action = True
        package_data = {"name": package_name, "source": source, "flag": flag}

        async def cb(m):
            await self._flutter_callback(m, json_mode)

        if not json_mode:
            console.print(Panel(f"Uninstalling [bold red]{package_name}[/bold red] from [cyan]{source}[/cyan]", border_style="red"))

        success = await self.executor.uninstall(package_data, callback=cb)
        if success:
            self.cache.invalidate_installed_cache()
            if not json_mode:
                console.print(Panel(f"Successfully uninstalled [bold red]{package_name}[/bold red]! ✨", border_style="green"))
                console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")

    async def run_update(self, package_name: str, source: str, json_mode: bool = False):
        """Update logic"""
        self.is_action = True
        package_data = {"name": package_name, "source": source}

        async def cb(m):
            await self._flutter_callback(m, json_mode)

        if not json_mode:
            target = "all packages" if package_name == "all" else f"[bold green]{package_name}[/bold green]"
            console.print(Panel(f"Updating {target} via [cyan]{source}[/cyan]", border_style="blue"))

        success = await self.executor.update(package_data, callback=cb)
        if success and not json_mode:
            console.print(Panel(f"Update completed! 🎉", border_style="green"))
            console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")

    async def run_check_updates(self, json_mode: bool = False):
        """Check for updates logic"""
        updates = await self.updater.check_all_updates()
        if json_mode:
            print(json.dumps(updates, ensure_ascii=False))
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

    async def run_recommendations(self, json_mode: bool = False):
        """Fetch dynamic recommendations"""
        try:
            timeout = aiohttp.ClientTimeout(total=15)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                await self.initialize(session)
                results = await self.recommender.get_recommendations() # type: ignore
                if json_mode:
                    print(json.dumps(results, ensure_ascii=False))
                else:
                    for app in results:
                        print(f"推荐: {app['name']} ({app['id']})")
        except Exception as e:
            if json_mode:
                print(json.dumps({"error": str(e), "results": []}))
            else:
                print(f"[Error] {e}")

    async def run_app_details(self, app_id: str, json_mode: bool = False):
        """Fetch dynamic app details"""
        try:
            timeout = aiohttp.ClientTimeout(total=15)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                await self.initialize(session)

                if "." in app_id:
                    details = await self.recommender.get_details(app_id) # type: ignore
                else:
                    details = await self.recommender.find_metadata(app_id) # type: ignore

                search_name = details.get("name") or app_id.split(".")[-1]
                variants_results = await self.manager.search_all(search_name) # type: ignore

                norm_target = self.manager._normalize_app_name(search_name) # type: ignore
                matched_app = None
                for res in variants_results:
                    if self.manager._normalize_app_name(res['name']) == norm_target: # type: ignore
                        matched_app = res
                        break

                if matched_app:
                    details["variants"] = matched_app.get("variants", [])
                    if not details.get("description") or len(details.get("description")) < 10:
                        details["description"] = matched_app.get("description", "")

                # Fetch extra info for Native/AUR variants (dependencies, size)
                for variant in details.get("variants", []):
                    if variant['source'] in ("Native", "Pacman", "AUR"):
                        try:
                            flag = "-Si" if variant['source'] in ("Native", "Pacman") else "-Sii"
                            proc = await asyncio.create_subprocess_exec(
                                "pacman" if variant['source'] in ("Native", "Pacman") else "yay",
                                flag, variant.get('name', search_name),
                                stdout=asyncio.subprocess.PIPE,
                                stderr=asyncio.subprocess.DEVNULL,
                                env={**os.environ, "LC_ALL": "C"}
                            )
                            stdout, _ = await proc.communicate()
                            if stdout:
                                info = stdout.decode()
                                deps_match = re.search(r"(?:Depends On|Depends)\s+:\s+(.*)", info)
                                if deps_match:
                                    variant["depends"] = deps_match.group(1).split()

                                dl_size_match = re.search(r"Download Size\s+:\s+(.*)", info)
                                if dl_size_match:
                                    variant["download_size"] = dl_size_match.group(1).strip()

                                ins_size_match = re.search(r"Installed Size\s+:\s+(.*)", info)
                                if ins_size_match:
                                    variant["installed_size"] = ins_size_match.group(1).strip()
                        except Exception: pass

                print(json.dumps(details, ensure_ascii=False))
        except Exception as e:
            print(json.dumps({"error": str(e)}))

    def _output_installed_pretty(self, installed_list):
        if not installed_list:
            console.print(Panel("No installed applications found.", border_style="yellow"))
            return

        table = Table(title="Installed Applications", show_header=True, header_style="bold blue")
        table.add_column("Source", style="cyan")
        table.add_column("Name", style="bold green")
        table.add_column("Version", style="dim")
        table.add_column("Description", style="italic")

        for app in installed_list:
            table.add_row(
                app['primary_source'],
                app['name'],
                app.get('version', 'N/A'),
                app.get('description', 'No description')[:50] + "..." if len(app.get('description', '')) > 50 else app.get('description', '')
            )

        console.print(table)
        console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")

    async def run_list_installed(self, json_mode: bool = False, force_refresh: bool = False):
        """List all installed AppImage, Flatpak, and Native applications"""
        if not force_refresh:
            cached = self.cache.get_installed_packages()
            if cached:
                if json_mode:
                    print(json.dumps(cached))
                else:
                    self._output_installed_pretty(cached)
                return

        installed_list = []

        # 1. Scan AppImage
        apps_dir = Path.home() / "Applications"
        if apps_dir.exists():
            for f in apps_dir.glob("*.AppImage"):
                installed_list.append({
                    "name": f.stem,
                    "primary_source": "AppImage",
                    "variants": [{"source": "AppImage"}],
                    "installed": True,
                    "description": f"Local AppImage at {f}",
                    "version": "Local",
                    "url": f.as_uri()
                })

        # 2. Scan Flatpak
        try:
            proc = await asyncio.create_subprocess_exec(
                "flatpak", "list", "--app", "--columns=name,application,version,description",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            )
            stdout, _ = await proc.communicate()
            if stdout:
                lines = stdout.decode().strip().splitlines()
                for line in lines:
                    parts = [p.strip() for p in line.split('\t')]
                    if len(parts) >= 2:
                        installed_list.append({
                            "name": parts[0],
                            "id": parts[1],
                            "primary_source": "Flatpak",
                            "variants": [{"source": "Flatpak"}],
                            "installed": True,
                            "version": parts[2] if len(parts) > 2 else "Unknown",
                            "description": parts[3] if len(parts) > 3 else f"Flatpak app {parts[1]}"
                        })
        except Exception as e:
            if not json_mode:
                await self._flutter_callback(f"Failed to scan Flatpaks: {e}", json_mode, level="ERROR")

        # 3. Scan Native (Pacman)
        try:
            proc = await asyncio.create_subprocess_exec(
                "pacman", "-Qqne",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            )
            stdout, _ = await proc.communicate()
            if stdout:
                for line in stdout.decode().strip().splitlines():
                    if line:
                        installed_list.append({
                            "name": line,
                            "primary_source": "Native",
                            "variants": [{"source": "Native"}],
                            "installed": True,
                            "description": "Native/AUR package",
                            "version": "Local"
                        })
        except Exception: pass

        if json_mode:
            print(json.dumps(installed_list))
        else:
            self._output_installed_pretty(installed_list)

        self.cache.save_installed_packages(installed_list)

    # --- Custom Repositories Methods ---
    async def run_list_custom_repos(self):
        """Combine and output all custom repositories from various sources"""
        flatpaks = await self.repo_manager.list_flatpak_remotes()
        pacmans = await self.repo_manager.list_pacman_repos()
        appimages = self.repo_manager.list_appimage_feeds()
        
        # Load local configuration custom repos definitions to compare/fill in details
        config_flatpak = self.config.get("custom_repos.flatpak", [])
        config_pacman = self.config.get("custom_repos.pacman", [])
        
        result = {
            "flatpak": flatpaks,
            "pacman": pacmans,
            "appimage": [{"name": Path(url).stem, "url": url} for url in appimages],
            "config_flatpak": config_flatpak,
            "config_pacman": config_pacman
        }
        print(json.dumps(result, ensure_ascii=False))

    async def run_add_custom_repo(self, repo_type: str, name: str, url: str, json_mode: bool = False):
        self.is_action = True
        async def cb(m):
            await self._flutter_callback(m, json_mode)

        success = False
        if repo_type == "flatpak":
            success = await self.repo_manager.add_flatpak_remote(name, url, callback=cb)
        elif repo_type == "pacman":
            success = await self.repo_manager.add_pacman_repo(name, url, callback=cb)
        elif repo_type == "appimage":
            success = self.repo_manager.add_appimage_feed(url)
            if success:
                await cb(f"[INFO] Successfully added AppImage feed: {url}")
            else:
                await cb(f"[ERROR] Failed to add AppImage feed: {url}")
        else:
            await cb(f"[ERROR] Invalid repo type: {repo_type}")

        if json_mode:
            print(json.dumps({"status": "success" if success else "error"}))

    async def run_remove_custom_repo(self, repo_type: str, name: str, json_mode: bool = False):
        self.is_action = True
        async def cb(m):
            await self._flutter_callback(m, json_mode)

        success = False
        if repo_type == "flatpak":
            success = await self.repo_manager.remove_flatpak_remote(name, callback=cb)
        elif repo_type == "pacman":
            success = await self.repo_manager.remove_pacman_repo(name, callback=cb)
        elif repo_type == "appimage":
            # For appimages, name parameter contains the url to remove
            success = self.repo_manager.remove_appimage_feed(name)
            if success:
                await cb(f"[INFO] Successfully removed AppImage feed: {name}")
            else:
                await cb(f"[ERROR] Failed to remove AppImage feed: {name}")
        else:
            await cb(f"[ERROR] Invalid repo type: {repo_type}")

        if json_mode:
            print(json.dumps({"status": "success" if success else "error"}))

    # --- AI Features Methods ---
    async def run_ai_explain(self, app_name: str, app_description: str = ""):
        res = await self.ai.explain_app(app_name, app_description)
        print(json.dumps({"response": res}, ensure_ascii=False))

    async def run_ai_recommend(self, prompt: str):
        # Hybrid Search: search locally for the query to provide candidates context to AI
        timeout = aiohttp.ClientTimeout(total=20)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            await self.initialize(session)
            # Find candidate apps matching query keyword (e.g. search broad keywords first)
            keywords = prompt.split()
            broad_query = keywords[0] if keywords else prompt
            candidates = await self.manager.search_all(broad_query) # type: ignore
            
            res = await self.ai.recommend_apps(prompt, candidates)
            print(json.dumps({"response": res}, ensure_ascii=False))

    async def run_ai_analyze_error(self, error_log: str):
        res = await self.ai.analyze_error(error_log)
        print(json.dumps({"response": res}, ensure_ascii=False))

    async def run_get_essentials(self):
        res = self.essentials.get_essentials()
        print(json.dumps(res, ensure_ascii=False))

    async def run_import_packages(self, filepath: str):
        res = self.essentials.import_from_file(filepath)
        print(json.dumps(res, ensure_ascii=False))

    async def run_export_packages(self, filepath: str):
        """Fetch all installed packages and export to a file"""
        installed = []

        # 1. Scan Native (Pacman)
        try:
            proc = await asyncio.create_subprocess_exec(
                "pacman", "-Qqne",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            )
            stdout, _ = await proc.communicate()
            if stdout:
                for line in stdout.decode().strip().splitlines():
                    if line:
                        installed.append({"name": line, "source": "Native"})
        except Exception: pass

        # 2. Scan Flatpak
        try:
            proc = await asyncio.create_subprocess_exec(
                "flatpak", "list", "--app", "--columns=application",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            )
            stdout, _ = await proc.communicate()
            if stdout:
                for line in stdout.decode().strip().splitlines():
                    if line:
                        installed.append({"name": line, "source": "Flatpak"})
        except Exception: pass

        # 3. Scan AUR (Optional, via yay -Qm)
        try:
            proc = await asyncio.create_subprocess_exec(
                "yay", "-Qm",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            )
            stdout, _ = await proc.communicate()
            if stdout:
                for line in stdout.decode().strip().splitlines():
                    if line:
                        pkg_name = line.split()[0]
                        installed.append({"name": pkg_name, "source": "AUR"})
        except Exception: pass

        try:
            # Ensure the directory exists
            os.makedirs(os.path.dirname(os.path.abspath(filepath)), exist_ok=True)
            with open(filepath, 'w') as f:
                json.dump(installed, f, ensure_ascii=False, indent=2)

            # Use unified callback if in JSON mode to show progress/log
            if self.json_mode:
                print(json.dumps({"status": "success", "count": len(installed)}))
            else:
                console.print(Panel(f"Successfully exported {len(installed)} packages to {filepath}", border_style="green"))
        except Exception as e:
            if self.json_mode:
                print(json.dumps({"status": "error", "message": str(e)}))
            else:
                console.print(f"[ERROR] Export failed: {e}")

    async def run_clean_system(self, json_mode: bool = False):
        """Cleanup logic: remove orphans and clean cache"""
        async def cb(m):
            await self._flutter_callback(m, json_mode)

        try:
            if not json_mode:
                console.print(Panel("Starting System Cleanup", border_style="blue"))

            await cb("[INFO] 正在检测孤立软件包...")
            proc = await asyncio.create_subprocess_exec(
                "pacman", "-Qtdq",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await proc.communicate()
            orphans = stdout.decode().strip().splitlines()

            if orphans:
                await cb(f"[INFO] 正在清理 {len(orphans)} 个孤立软件包...")
                if not await self.executor._ensure_privileged(cb):
                    return

                proc = await asyncio.create_subprocess_exec(
                    "sudo", "pacman", "-Rs", "--noconfirm", *orphans,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                await proc.communicate()
            else:
                await cb("[INFO] 未发现孤立软件包。")

            await cb("[INFO] 正在清理包缓存...")
            if not await self.executor._ensure_privileged(cb):
                return
            proc = await asyncio.create_subprocess_exec(
                "sudo", "pacman", "-Scc", "--noconfirm",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            await proc.communicate()

            await cb("[INFO] 系统清理完成！")
            if json_mode:
                print(json.dumps({"status": "success"}))
            else:
                console.print(Panel("System Cleanup Finished! ✨", border_style="green"))
                console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")
        except Exception as e:
            await cb(f"[ERROR] 清理失败: {e}")
            if json_mode:
                print(json.dumps({"status": "error", "message": str(e)}))

    async def run_ai_summary(self, json_mode: bool = False):
        """Generate AI project summary."""
        res = await self.ai.summarize_project()
        if json_mode:
            print(json.dumps({"response": res}, ensure_ascii=False))
        else:
            print(f"AI Summary:\n{res}")
    def _output_json(self, results):
        output = []
        for item in results:
            output.append({
                "name": str(item.get("name", "Unknown")),
                "description": str(item.get("description", "")),
                "installed": bool(item.get("installed", False) or item.get("is_installed", False)),
                "primary_source": str(item.get("primary_source") or item.get("source") or "Native"),
                "url": str(item.get("url") or ""),
                "variants": item.get("variants", []),
                "version": str(item.get("last_version") or item.get("version") or "N/A"),
                "score": int(item.get("score", 0)),
                "icon": item.get("icon"),
                "is_exact_match": item.get("is_exact_match", False)
            })
        sys.stdout.write(json.dumps(output, ensure_ascii=False) + '\n')
        sys.stdout.flush()

    def _output_pretty(self, query, results):
        if not results:
            console.print(Panel(f"No results found for [bold cyan]'{query}'[/bold cyan]", title="Search Results", border_style="yellow"))
            return

        table = Table(title=f"Search Results for '{query}'", show_header=True, header_style="bold magenta")
        table.add_column("#", style="dim", width=3)
        table.add_column("Name", style="bold green")
        table.add_column("Status", width=12)
        table.add_column("Sources", style="cyan")
        table.add_column("Description", style="italic")

        for i, item in enumerate(results[:15]):
            is_installed = item.get("installed") or item.get("is_installed")
            status = "[blue]Installed[/blue]" if is_installed else "[dim]Not Installed[/dim]"
            sources = [v['source'] for v in item.get('variants', [])]
            source_str = ", ".join(sources)
            desc = item.get('description', 'No description')
            if len(desc) > 60:
                desc = desc[:57] + "..."

            table.add_row(str(i+1), item['name'], status, source_str, desc)

        console.print(table)
        console.print(f"\n[italic]{get_friendly_message()}[/italic]\n")


async def main():
    main.json_mode_active = "--json" in sys.argv
    parser = argparse.ArgumentParser(
        description="Omnistore: all-in-one software manager for Arch Linux and beyond.\n\n",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    group = parser.add_mutually_exclusive_group(required=False)
    group.add_argument("-S", "--search", metavar="QUERY",
                       help="Search for software packages")
    group.add_argument("-I", "--install", metavar="PACKAGE",
                       help="Install software packages")
    group.add_argument("-R", "--remove", metavar="PACKAGE",
                       help="Uninstall software packages")
    group.add_argument("-U", "--update", metavar="PACKAGE",
                       help="Update software packages (use 'all' for all packages in source)")
    group.add_argument("-C", "--check-updates", action="store_true",
                       help="Check for updates for all installed packages")
    group.add_argument("-L", "--list-installed", action="store_true",
                       help="List all installed AppImage and Flatpak packages")
    parser.add_argument("--force-refresh", action="store_true", help="Force refresh installed cache")
    group.add_argument("--launch", metavar="PACKAGE", help="Launch a software package")
    group.add_argument("--recommend", action="store_true", help="Get dynamic recommendations")
    group.add_argument("--essentials", action="store_true", help="Get essential packages")
    group.add_argument("--import-packages", metavar="FILEPATH", help="Import packages from file")
    group.add_argument("--export-packages", metavar="FILEPATH", help="Export installed packages to file")
    group.add_argument("--clean-system", action="store_true", help="Remove orphans and clean cache")
    parser.add_argument("--ai-summary", action="store_true", help="Generate AI project summary")
    group.add_argument("--details", metavar="APP_ID", help="Get dynamic app details")
    group.add_argument("--check-env", action="store_true", help="Check system environment")
    group.add_argument("--bootstrap", action="store_true", help="Bootstrap environment")
    
    # Custom repositories options
    group.add_argument("--list-custom-repos", action="store_true", help="List custom repositories")
    group.add_argument("--add-custom-repo", metavar="TYPE,NAME,URL", help="Add custom repo (e.g. flatpak,flathub-beta,https://dl.flathub.org/beta-repo/)")
    group.add_argument("--remove-custom-repo", metavar="TYPE,NAME", help="Remove custom repo (e.g. flatpak,flathub-beta)")

    # AI options
    group.add_argument("--ai-explain", metavar="APP_NAME", help="Ask AI to explain package details")
    group.add_argument("--ai-recommend", metavar="PROMPT", help="Ask AI to recommend apps based on prompt")
    group.add_argument("--ai-analyze-error", metavar="ERROR_LOG", help="Ask AI to analyze installation error logs")

    parser.add_argument("--json", action="store_true",
                         help="Output results in JSON format")
    parser.add_argument("--source", choices=["AUR", "Flatpak", "AppImage", "Native"],
                         default="AUR", help="Specify the source for installation (default: AUR)")
    parser.add_argument(
        "--url", help="For AppImage, specify the direct download URL")
    parser.add_argument("--version", action="version",
                         version="Omnistore 0.1.0")
    parser.add_argument("--debug", action="store_true",
                         help="Enable debug mode with verbose logging")
    parser.add_argument("--get-config", action="store_true",
                         help="Get the full configuration as JSON")
    parser.add_argument("--set-config", metavar="CONFIG_JSON",
                         help="Set the full configuration using a JSON string")
    parser.add_argument("--ai-desc", help="Helper argument for --ai-explain to provide a description")

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()
    backend = OmnistoreBackend(json_mode=args.json)

    if not args.json:
        console.print(Panel.fit(f"[bold blue]OmniStore[/bold blue] v0.1.0\n[dim]{get_friendly_message()}[/dim]", border_style="blue"))

    import signal
    def handle_term(sig, frame):
        if backend and hasattr(backend, "executor"):
            backend.executor.stop()
        sys.exit(0)
    
    signal.signal(signal.SIGTERM, handle_term)
    signal.signal(signal.SIGINT, handle_term)

    # Validate active argument
    active_args = [
        args.search, args.install, args.remove, args.update, args.check_updates,
        args.get_config, args.set_config, args.list_installed, args.launch,
        args.recommend, args.essentials, args.import_packages, args.export_packages,
        args.clean_system, args.ai_summary, args.details, args.check_env, 
        args.bootstrap, args.list_custom_repos, args.add_custom_repo, args.remove_custom_repo,
        args.ai_explain, args.ai_recommend, args.ai_analyze_error
    ]
    if not any(active_args):
        parser.print_help()
        return

    # --- Dispatch Logic ---

    if args.get_config:
        config = backend.config.data
        print(json.dumps(config, ensure_ascii=False))

    elif args.set_config:
        try:
            input_data = sys.stdin.read().strip()
            if not input_data:
                input_data = args.set_config

            if not input_data or input_data == "true":
                print(json.dumps({"status": "error", "message": "[ERROR] No configuration data provided"}))
                sys.exit(1)

            success = backend.config.save(new_config=json.loads(input_data))
            if success:
                print(json.dumps({"status": "success", "message": "[INFO] Configuration saved successfully"}))
            else:
                print(json.dumps({"status": "error", "message": "[ERROR] Failed to save configuration"}))
        except Exception as e:
            print(json.dumps({"status": "error", "message": f"[ERROR] {str(e)}"}))
            sys.exit(1)

    elif args.search:
        await backend.run_search(args.search, json_mode=args.json)

    elif args.install:
        await backend.run_install(
            args.install,
            source=args.source,
            url=args.url,
            json_mode=args.json
        )

    elif args.remove:
        await backend.run_uninstall(
            args.remove,
            source=args.source,
            json_mode=args.json,
            flag=args.remove
        )

    elif args.update:
        await backend.run_update(
            args.update,
            source=args.source,
            json_mode=args.json
        )

    elif args.check_updates:
        await backend.run_check_updates(json_mode=args.json)

    elif args.list_installed:
        await backend.run_list_installed(json_mode=args.json, force_refresh=args.force_refresh)

    elif args.ai_summary:
        await backend.run_ai_summary(json_mode=args.json)

    elif args.details:
        await backend.run_app_details(args.details, json_mode=args.json)

    elif args.recommend:
        await backend.run_recommendations(json_mode=args.json)

    elif args.essentials:
        await backend.run_get_essentials()

    elif args.import_packages:
        await backend.run_import_packages(args.import_packages)

    elif args.export_packages:
        await backend.run_export_packages(args.export_packages)

    elif args.clean_system:
        await backend.run_clean_system(json_mode=args.json)

    elif args.check_env:
        status = await backend.env.check_env()
        print(json.dumps(status, ensure_ascii=False))

    elif args.bootstrap:
        async def cb(m):
            await backend._flutter_callback(m, args.json)
        success = await backend.env.bootstrap(callback=cb)
        if args.json:
            print(json.dumps({"status": "success" if success else "error"}))

    elif args.launch:
        import subprocess
        try:
            target = args.launch
            if args.source == "Flatpak":
                subprocess.Popen(["flatpak", "run", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif args.source == "AppImage":
                app_path = Path.home() / f"Applications/{target}.AppImage"
                if app_path.exists():
                    subprocess.Popen([str(app_path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                else:
                    found = list((Path.home() / "Applications").glob(f"*{target}*.AppImage"))
                    if found:
                        subprocess.Popen([str(found[0])], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                subprocess.Popen([target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if args.json:
                print(json.dumps({"status": "success", "message": f"[INFO] Launched {target}"}))
            else:
                print(f"[INFO] Launched {target}")
        except Exception as e:
            if args.json:
                print(json.dumps({"status": "error", "message": f"[ERROR] Launch failed: {str(e)}"}))
            else:
                print(f"[ERROR] Launch failed: {str(e)}")

    # Custom repo dispatching
    elif args.list_custom_repos:
        await backend.run_list_custom_repos()

    elif args.add_custom_repo:
        try:
            parts = args.add_custom_repo.split(',', 2)
            if len(parts) < 3:
                # Fallback for AppImage type where name isn't strictly required (url is second param)
                if len(parts) == 2 and parts[0] == "appimage":
                    await backend.run_add_custom_repo("appimage", "", parts[1], json_mode=args.json)
                else:
                    print(json.dumps({"status": "error", "message": "[ERROR] Add custom repo arguments must be: type,name,url"}))
            else:
                await backend.run_add_custom_repo(parts[0], parts[1], parts[2], json_mode=args.json)
        except Exception as e:
            print(json.dumps({"status": "error", "message": f"[ERROR] Add custom repo parsing failed: {e}"}))

    elif args.remove_custom_repo:
        try:
            parts = args.remove_custom_repo.split(',', 1)
            if len(parts) < 2:
                print(json.dumps({"status": "error", "message": "[ERROR] Remove custom repo arguments must be: type,name"}))
            else:
                await backend.run_remove_custom_repo(parts[0], parts[1], json_mode=args.json)
        except Exception as e:
            print(json.dumps({"status": "error", "message": f"[ERROR] Remove custom repo parsing failed: {e}"}))

    # AI dispatching
    elif args.ai_explain:
        await backend.run_ai_explain(args.ai_explain, args.ai_desc or "")

    elif args.ai_recommend:
        await backend.run_ai_recommend(args.ai_recommend)

    elif args.ai_analyze_error:
        await backend.run_ai_analyze_error(args.ai_analyze_error)


if __name__ == "__main__":
    import asyncio
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
    except Exception:
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)
