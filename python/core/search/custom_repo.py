import logging
import os
import re
import asyncio
from core.subprocess_utils import safe_subprocess
import tempfile
import shutil
from typing import Dict, List, Any
from core.downloader.manager import InstallExecutor


class CustomRepoManager:
    OFFICIAL_MEO_REPOSITORIES = frozenset({"meo", "meo-beta"})
    def __init__(self, config_manager, executor):
        self.cm = config_manager
        self.executor = executor

    # --- Flatpak Custom Remotes ---
    async def list_flatpak_remotes(self) -> List[Dict[str, str]]:
        """List flatpak remotes by running flatpak remotes command."""
        try:
            async with safe_subprocess(
                "flatpak", "remotes", "--columns=name,url",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            ) as proc:
                stdout, _ = await proc.communicate()
                if not stdout:
                    return []
            
                remotes = []
                for line in stdout.decode().strip().splitlines():
                    if not line.strip():
                        continue
                    parts = line.split('\t')
                    if len(parts) >= 2:
                        remotes.append({"name": parts[0].strip(), "url": parts[1].strip()})
                return remotes
        except Exception as e:
            return []

    async def add_flatpak_remote(self, name: str, url: str, callback=None) -> bool:
        """Add a custom Flatpak remote (runs in user space, no sudo needed)."""
        try:
            if callback:
                await callback(f"[INFO] Adding Flatpak remote '{name}' ({url})...")
            
            async with safe_subprocess(
                "flatpak", "remote-add", "--user", "--if-not-exists", name, url,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT
            ) as proc:
                stdout, _ = await proc.communicate()
                success = proc.returncode == 0
                if success:
                    # Sync into config.yaml
                    custom_flatpaks = self.cm.get("custom_repos.flatpak", [])
                    for r in custom_flatpaks:
                        if r.get("name") == name:
                            break
                    else:
                        custom_flatpaks.append({"name": name, "url": url})
                        self.cm.set("custom_repos.flatpak", custom_flatpaks)
                    if callback:
                        await callback(f"[INFO] Successfully added Flatpak remote '{name}'.")
                else:
                    err_msg = stdout.decode().strip() if stdout else "Unknown error"
                    if callback:
                        await callback(f"[ERROR] Failed to add remote: {err_msg}")
                return success
        except Exception as e:
            if callback:
                await callback(f"[ERROR] Failed to add flatpak remote: {e}")
            return False

    async def remove_flatpak_remote(self, name: str, callback=None) -> bool:
        """Remove a custom Flatpak remote."""
        try:
            if callback:
                await callback(f"[INFO] Removing Flatpak remote '{name}'...")
            
            async with safe_subprocess(
                "flatpak", "remote-delete", "--user", "--force", name,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT
            ) as proc:
                stdout, _ = await proc.communicate()
                success = proc.returncode == 0
                if success:
                    # Sync from config.yaml
                    custom_flatpaks = self.cm.get("custom_repos.flatpak", [])
                    custom_flatpaks = [r for r in custom_flatpaks if r.get("name") != name]
                    self.cm.set("custom_repos.flatpak", custom_flatpaks)
                    if callback:
                        await callback(f"[INFO] Successfully removed Flatpak remote '{name}'.")
                else:
                    err_msg = stdout.decode().strip() if stdout else "Unknown error"
                    if callback:
                        await callback(f"[ERROR] Failed to remove remote: {err_msg}")
                return success
        except Exception as e:
            if callback:
                await callback(f"[ERROR] Failed to remove flatpak remote: {e}")
            return False

    # --- Pacman Custom Repositories (/etc/pacman.conf) ---
    async def list_pacman_repos(self) -> List[Dict[str, str]]:
        """Parse /etc/pacman.conf to find custom repositories."""
        repos = []
        if not os.path.exists("/etc/pacman.conf"):
            return repos

        try:
            with open("/etc/pacman.conf", "r", encoding="utf-8") as f:
                content = f.read()
            
            # Find blocks like:
            # [repo_name]
            # SigLevel = ...
            # Server = ...
            pattern = re.compile(r'^\[([^\]\s]+)\]', re.MULTILINE)
            matches = list(pattern.finditer(content))
            
            # Standard repositories to ignore
            standard_repos = {"options", "core", "extra", "community", "multilib"}
            
            for i, match in enumerate(matches):
                repo_name = match.group(1)
                if repo_name in standard_repos:
                    continue
                
                # Extract block text
                start = match.end()
                end = matches[i+1].start() if i + 1 < len(matches) else len(content)
                block = content[start:end]
                
                # Find server URL
                server_match = re.search(r'^\s*Server\s*=\s*(.+)$', block, re.MULTILINE)
                url = server_match.group(1).strip() if server_match else ""
                
                repos.append({"name": repo_name, "url": url})
        except Exception as e:
            logging.error(f"Failed to parse pacman custom repos: {e}")
        return repos

    async def add_pacman_repo(self, name: str, url: str, callback=None) -> bool:
        """Reject custom Pacman repositories until signed repository support exists."""
        if callback:
            await callback(
                "[ERROR] Custom Pacman repositories are disabled until "
                "signature verification and keyring enrollment are implemented."
            )
        return False

    async def remove_pacman_repo(self, name: str, callback=None) -> bool:
        """Remove a custom repository from /etc/pacman.conf (requires sudo privileges)."""
        # Official Meo repositories are owned by the mutually-conflicting
        # meo-channel-* packages.  Removing their Include-backed entries here
        # would leave pacman and the selected channel package disagreeing.
        normalized_name = name.strip().casefold()
        if not re.fullmatch(r"[A-Za-z0-9@._+:-]{1,128}", name.strip()):
            if callback:
                await callback("[ERROR] Invalid Pacman repository name.")
            return False
        if normalized_name in self.OFFICIAL_MEO_REPOSITORIES:
            if callback:
                await callback(
                    "[ERROR] Official Meo repositories are managed by the update "
                    "channel package. Use OmniStore's Update channel controls."
                )
            return False
        if callback:
            await callback(f"[INFO] Requesting authorization to modify /etc/pacman.conf...")

        if not await self.executor._ensure_privileged(callback):
            return False

        try:
            with open("/etc/pacman.conf", "r", encoding="utf-8") as f:
                conf = f.read()

            if f"[{name}]" not in conf:
                if callback:
                    await callback(f"[WARNING] Repository [{name}] does not exist in pacman.conf.")
                return True

            # Regex search for block starting with [name] up to next block
            pattern = re.compile(rf'^\s*\[{re.escape(name.strip())}\].*?((?=^\s*\[)|$)', re.MULTILINE | re.DOTALL)
            modified_conf = pattern.sub('', conf)

            # Clean up potential trailing double newlines
            modified_conf = re.sub(r'\n{3,}', '\n\n', modified_conf)

            temp_fd, temp_path = tempfile.mkstemp()
            try:
                with os.fdopen(temp_fd, 'w', encoding='utf-8') as tmpf:
                    tmpf.write(modified_conf)

                async with safe_subprocess(
                    "sudo", "cp", temp_path, "/etc/pacman.conf",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.STDOUT
                ) as proc:
                    await proc.wait()
            finally:
                if os.path.exists(temp_path):
                    os.remove(temp_path)

            if proc.returncode == 0:
                # Sync config.yaml
                custom_pacman = self.cm.get("custom_repos.pacman", [])
                custom_pacman = [r for r in custom_pacman if r.get("name") != name]
                self.cm.set("custom_repos.pacman", custom_pacman)
                
                if callback:
                    await callback(f"[INFO] Successfully removed Pacman repository [{name}]. Syncing databases...")
                
                async with safe_subprocess(
                    "sudo", "pacman", "-Sy",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.STDOUT
                ) as sync_proc:
                    await sync_proc.wait()
                    return True
            else:
                if callback:
                    await callback("[ERROR] Failed to write /etc/pacman.conf.")
                return False

        except Exception as e:
            if callback:
                await callback(f"[ERROR] Failed to remove pacman repo: {e}")
            return False

    # --- AppImage Custom Feeds ---
    def list_appimage_feeds(self) -> List[str]:
        return self.cm.get("custom_repos.appimage", [])

    def add_appimage_feed(self, url: str) -> bool:
        feeds = self.list_appimage_feeds()
        if url not in feeds:
            feeds.append(url)
            self.cm.set("custom_repos.appimage", feeds)
            return True
        return False

    def remove_appimage_feed(self, url: str) -> bool:
        feeds = self.list_appimage_feeds()
        if url in feeds:
            feeds.remove(url)
            self.cm.set("custom_repos.appimage", feeds)
            return True
        return False
