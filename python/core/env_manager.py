import os
import subprocess
import asyncio
from core.subprocess_utils import safe_subprocess
from pathlib import Path
from typing import Dict, List, Optional

class EnvManager:
    def __init__(self):
        self.is_arch = self._check_arch()

    def _check_arch(self) -> bool:
        """Check if the system is Arch Linux or Arch-based."""
        try:
            if os.path.exists("/etc/os-release"):
                with open("/etc/os-release", "r") as f:
                    content = f.read().lower()
                    return "arch" in content
            return False
        except Exception:
            return False

    async def check_env(self) -> Dict:
        """
        Returns a status dictionary for various environment requirements.
        Levels: 'ok', 'warning' (fixable), 'error' (non-fatal), 'fatal' (cannot run).
        """
        status = {
            "is_arch": {
                "status": "ok" if self.is_arch else "fatal",
                "message": "Arch Linux detected" if self.is_arch else "System is not Arch-based"
            },
            "git": {
                "status": "ok" if await self._has_cmd("git") else "warning",
                "message": "Git is installed" if await self._has_cmd("git") else "Git is missing"
            },
            "base-devel": {
                "status": "ok" if await self._has_pkg("base-devel") else "warning",
                "message": "Build tools detected" if await self._has_pkg("base-devel") else "Build tools (base-devel) missing"
            },
            "yay": {
                "status": "ok" if await self._has_cmd("yay") else "warning",
                "message": "AUR helper (yay) found" if await self._has_cmd("yay") else "AUR helper (yay) missing"
            },
            "libdbusmenu-gtk3": {
                "status": "ok" if await self._has_pkg("libdbusmenu-gtk3") else "warning",
                "message": "Tray menu support detected" if await self._has_pkg("libdbusmenu-gtk3") else "Tray menu support (libdbusmenu-gtk3) missing"
            },
            "libappindicator-gtk3": {
                "status": "ok" if await self._has_pkg("libappindicator-gtk3") or await self._has_pkg("libayatana-appindicator") else "warning",
                "message": "Tray indicator support detected" if await self._has_pkg("libappindicator-gtk3") or await self._has_pkg("libayatana-appindicator") else "Tray indicator support (libappindicator-gtk3) missing"
            }
        }
        return status

    async def _has_cmd(self, cmd: str) -> bool:
        try:
            async with safe_subprocess("which", cmd, stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL) as proc:
                await proc.wait()
                return proc.returncode == 0
        except Exception:
            return False

    async def _has_pkg(self, pkg: str) -> bool:
        if not await self._has_cmd("pacman"):
            return False
        try:
            async with safe_subprocess("pacman", "-Qq", pkg, stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL) as proc:
                await proc.wait()
                if proc.returncode == 0:
                    return True
            async with safe_subprocess("pacman", "-Qg", pkg, stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL) as proc:
                await proc.wait()
                return proc.returncode == 0
        except Exception:
            return False

    async def bootstrap(self, callback=None):
        """Install git, base-devel, libraries and yay if missing."""
        if not self.is_arch:
            if callback: await callback("[ERROR] Cannot bootstrap on non-Arch system.")
            return False

        # 1. Install base dependencies and libraries
        deps = ["git", "base-devel", "libdbusmenu-gtk3"]
        # Use libayatana-appindicator if libappindicator-gtk3 is not in repos (Arch often uses Ayatana now)
        if not await self._has_pkg("libappindicator-gtk3") and not await self._has_pkg("libayatana-appindicator"):
            deps.append("libayatana-appindicator")
        elif await self._has_pkg("libappindicator-gtk3"):
             # It's fine
             pass

        needed = []
        for d in deps:
            if d == "git":
                if not await self._has_cmd(d):
                    needed.append(d)
            else:
                if not await self._has_pkg(d):
                    needed.append(d)

        if needed:
            if callback: await callback(f"[INFO] Installing dependencies: {', '.join(needed)}...")
            success = await self._run_pacman(["-S", "--noconfirm", "--needed"] + needed, callback)
            if not success:
                if callback: await callback("[ERROR] Failed to install dependencies.")
                return False

        # 2. Install yay
        if not await self._has_cmd("yay"):
            if callback: await callback("[INFO] Building and installing yay (this may take a while)...")
            success = await self._install_yay(callback)
            if not success:
                return False

        if callback: await callback("[INFO] Environment bootstrap completed successfully.")
        return True

    async def _run_pacman(self, args: List[str], callback) -> bool:
        # Needs sudo
        cmd = ["sudo", "pacman"] + args
        async with safe_subprocess(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT
        ) as proc:
            if proc.stdout:
                while True:
                    line = await proc.stdout.readline()
                    if not line: break
                    if callback: await callback(f"[INFO] {line.decode().strip()}")
            await proc.wait()
            return proc.returncode == 0

    async def _install_yay(self, callback) -> bool:
        import tempfile
        import shutil

        tmpdir = tempfile.mkdtemp()
        try:
            if callback: await callback("[INFO] Cloning yay repository...")
            async with safe_subprocess(
                "git", "clone", "https://aur.archlinux.org/yay-bin.git", tmpdir,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT
            ) as clone:
                await clone.wait()
                if clone.returncode != 0:
                    if callback: await callback("[ERROR] Failed to clone yay repository.")
                    return False

                if callback: await callback("[INFO] Building yay package...")
                # makepkg cannot be run as root
                async with safe_subprocess(
                    "makepkg", "-si", "--noconfirm",
                    cwd=tmpdir,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.STDOUT
                ) as makepkg:
                    if makepkg.stdout:
                        while True:
                            line = await makepkg.stdout.readline()
                            if not line: break
                            if callback: await callback(f"[INFO] {line.decode().strip()}")
                    await makepkg.wait()
                    return makepkg.returncode == 0
        except Exception as e:
            if callback: await callback(f"[ERROR] Yay installation failed: {e}")
            return False
        finally:
            shutil.rmtree(tmpdir)
