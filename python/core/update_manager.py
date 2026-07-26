import asyncio
import os
from core.subprocess_utils import safe_subprocess
import shutil
import re
from pathlib import Path
from typing import List, Dict, Any, Optional

class UpdateManager:
    """
    Unified Update Manager inspired by Shelly-ALPM and CachyOS cachy-update logic.
    Provides non-destructive update discovery, database lock checks, and multi-source update aggregation.
    """
    def __init__(self, config=None, backend=None):
        self.config = config
        self.backend = backend
        self.db_lock_path = Path("/var/lib/pacman/db.lck")

    def check_pacman_db_lock(self) -> Dict[str, Any]:
        """
        CachyOS / Shelly style safety check:
        Detects if /var/lib/pacman/db.lck exists to prevent lock collision crashes.
        """
        is_locked = self.db_lock_path.exists()
        return {
            "locked": is_locked,
            "lock_file": str(self.db_lock_path) if is_locked else None,
            "message": "Pacman database is currently locked by another process." if is_locked else "Pacman DB is unlocked."
        }

    async def check_all_updates(self) -> List[Dict[str, Any]]:
        """
        Aggregates updates from all supported sources (Native Pacman, AUR, Flatpak, AppImage).
        """
        tasks = []
        include_aur = True
        if self.config:
            include_aur = self.config.get("updates.include_aur_in_update_all", True)

        if shutil.which("pacman"):
            tasks.append(self.check_pacman_updates())
        if include_aur and (shutil.which("yay") or shutil.which("paru")):
            tasks.append(self.check_aur_updates())
        if shutil.which("flatpak"):
            tasks.append(self.check_flatpak_updates())

        results = await asyncio.gather(*tasks, return_exceptions=True)

        combined: List[Dict[str, Any]] = []
        for res in results:
            if isinstance(res, list):
                combined.extend(res)
            elif isinstance(res, Exception):
                print(f"[UpdateManager] Error checking updates: {res}")

        return combined

    async def check_pacman_updates(self) -> List[Dict[str, Any]]:
        """Check for native package updates using checkupdates (pacman-contrib) or pacman -Qu"""
        lock_status = self.check_pacman_db_lock()
        if lock_status["locked"]:
            # If DB is locked, return notice rather than hanging or crashing
            print(f"[UpdateManager] Warning: {lock_status['message']}")

        if shutil.which("checkupdates"):
            return await self._run_qu_command(["checkupdates"], "Pacman", "Native package update")

        if not lock_status["locked"]:
            return await self._run_qu_command(["pacman", "-Qu"], "Pacman", "Native package update")
        return []

    async def check_aur_updates(self) -> List[Dict[str, Any]]:
        """Check for AUR updates using yay -Qua or paru -Qua"""
        aur_helper = None
        if shutil.which("yay"):
            aur_helper = ["yay", "-Qua"]
        elif shutil.which("paru"):
            aur_helper = ["paru", "-Qua"]

        if not aur_helper:
            return []

        return await self._run_qu_command(aur_helper, "AUR", "Arch User Repository update")

    async def _run_qu_command(self, cmd: List[str], source: str, default_desc: str) -> List[Dict[str, Any]]:
        try:
            async with safe_subprocess(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
                env={**os.environ, "LC_ALL": "C"}
            ) as proc:
                stdout, _ = await proc.communicate()
                if not stdout:
                    return []

                updates = []
                for line in stdout.decode(errors="ignore").strip().splitlines():
                    # Format: pkgname old_version -> new_version
                    match = re.match(r"^([^\s]+)\s+([^\s]+)\s+->\s+([^\s]+)", line)
                    if match:
                        name, old_ver, new_ver = match.groups()
                        updates.append({
                            "id": name,
                            "name": name,
                            "source": source,
                            "primary_source": source,
                            "current_version": old_ver,
                            "new_version": new_ver,
                            "description": f"{default_desc}: {old_ver} -> {new_ver}",
                            "installed": True,
                            "managed": True,
                            "update_available": True
                        })
                return updates
        except Exception:
            return []

    async def check_flatpak_updates(self) -> List[Dict[str, Any]]:
        """Check for Flatpak updates"""
        if not shutil.which("flatpak"):
            return []

        try:
            async with safe_subprocess(
                "flatpak", "list", "--updates", "--columns=name,application,version,new-version",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
                env={**os.environ, "LC_ALL": "C"}
            ) as proc:
                stdout, _ = await proc.communicate()
                if not stdout:
                    return []

                updates = []
                for line in stdout.decode(errors="ignore").strip().splitlines():
                    parts = [p.strip() for p in line.split('\t')]
                    if len(parts) >= 4:
                        updates.append({
                            "id": parts[1],
                            "name": parts[0],
                            "source": "Flatpak",
                            "primary_source": "Flatpak",
                            "current_version": parts[2],
                            "new_version": parts[3],
                            "description": f"Flatpak update: {parts[0]} ({parts[2]} -> {parts[3]})",
                            "installed": True,
                            "managed": True,
                            "update_available": True
                        })
                return updates
        except Exception:
            return []
