import asyncio
from core.subprocess_utils import safe_subprocess
import shutil
import re
from typing import List, Dict

class UpdateManager:
    def __init__(self, config=None):
        self.config = config

    async def check_all_updates(self) -> List[Dict]:
        tasks = []
        include_aur = True
        if self.config:
            include_aur = self.config.get("updates.include_aur_in_update_all", True)

        if shutil.which("pacman"):
            tasks.append(self.check_pacman_updates())
        if shutil.which("yay") and include_aur:
            tasks.append(self.check_aur_updates())
        if shutil.which("flatpak"):
            tasks.append(self.check_flatpak_updates())

        results = await asyncio.gather(*tasks, return_exceptions=True)

        combined = []
        for res in results:
            if isinstance(res, list):
                combined.extend(res)
            elif isinstance(res, Exception):
                print(f"[UpdateManager] Error checking updates: {res}")

        return combined

    async def check_pacman_updates(self) -> List[Dict]:
        """Check for native package updates using checkupdates (pacman-contrib)"""
        if not shutil.which("checkupdates"):
            # Fallback to pacman -Qu if checkupdates is not installed
            # Note: pacman -Qu only works if the DB is already synced (pacman -Sy)
            return await self._run_qu_command(["pacman", "-Qu"], "Native")

        return await self._run_qu_command(["checkupdates"], "Native")

    async def check_aur_updates(self) -> List[Dict]:
        """Check for AUR updates using yay -Qua"""
        if not shutil.which("yay"):
            return []
        return await self._run_qu_command(["yay", "-Qua"], "AUR")

    async def _run_qu_command(self, cmd: List[str], source: str) -> List[Dict]:
        try:
            async with safe_subprocess(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            ) as proc:
                stdout, _ = await proc.communicate()
                if not stdout:
                    return []

                updates = []
                for line in stdout.decode().strip().splitlines():
                    # Format: pkgname old_version -> new_version
                    match = re.match(r"^([^\s]+)\s+([^\s]+)\s+->\s+([^\s]+)", line)
                    if match:
                        name, old_ver, new_ver = match.groups()
                        updates.append({
                            "name": name,
                            "source": source,
                            "current_version": old_ver,
                            "new_version": new_ver,
                            "description": f"Update available from {source}"
                        })
                return updates
        except Exception:
            return []

    async def check_flatpak_updates(self) -> List[Dict]:
        """Check for Flatpak updates"""
        if not shutil.which("flatpak"):
            return []

        try:
            # columns: name, application, version, new-version
            async with safe_subprocess(
                "flatpak", "list", "--updates", "--columns=name,application,version,new-version",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            ) as proc:
                stdout, _ = await proc.communicate()
                if not stdout:
                    return []

                updates = []
                for line in stdout.decode().strip().splitlines():
                    parts = [p.strip() for p in line.split('\t')]
                    if len(parts) >= 4:
                        updates.append({
                            "name": parts[0],
                            "id": parts[1],
                            "source": "Flatpak",
                            "current_version": parts[2],
                            "new_version": parts[3],
                            "description": f"Flatpak update: {parts[1]}"
                        })
                return updates
        except Exception:
            return []
