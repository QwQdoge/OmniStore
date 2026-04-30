import os
import subprocess
import asyncio
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
                "status": "ok" if self._has_cmd("git") else "warning",
                "message": "Git is installed" if self._has_cmd("git") else "Git is missing"
            },
            "base-devel": {
                "status": "ok" if self._has_pkg("base-devel") else "warning",
                "message": "Build tools detected" if self._has_pkg("base-devel") else "Build tools (base-devel) missing"
            },
            "yay": {
                "status": "ok" if self._has_cmd("yay") else "warning",
                "message": "AUR helper (yay) found" if self._has_cmd("yay") else "AUR helper (yay) missing"
            }
        }
        return status

    def _has_cmd(self, cmd: str) -> bool:
        return subprocess.run(["which", cmd], capture_output=True).returncode == 0

    def _has_pkg(self, pkg: str) -> bool:
        # For base-devel, it's a group, so check pacman -Qg or just try to see if it's there
        # Simpler check: see if make/gcc exists as proxy for base-devel if pacman check is slow
        if not self._has_cmd("pacman"):
            return False
        res = subprocess.run(["pacman", "-Qq", pkg], capture_output=True)
        if res.returncode == 0:
            return True
        # Check if it's a group
        res = subprocess.run(["pacman", "-Qg", pkg], capture_output=True)
        return res.returncode == 0

    async def bootstrap(self, callback=None):
        """Install git, base-devel, and yay if missing."""
        if not self.is_arch:
            if callback: await callback("[ERROR] Cannot bootstrap on non-Arch system.")
            return False

        # 1. Install git and base-devel
        if not self._has_cmd("git") or not self._has_pkg("base-devel"):
            if callback: await callback("[INFO] Installing git and base-devel...")
            success = await self._run_pacman(["-S", "--noconfirm", "--needed", "git", "base-devel"], callback)
            if not success:
                if callback: await callback("[ERROR] Failed to install base dependencies.")
                return False

        # 2. Install yay
        if not self._has_cmd("yay"):
            if callback: await callback("[INFO] Building and installing yay (this may take a while)...")
            success = await self._install_yay(callback)
            if not success:
                return False

        if callback: await callback("[INFO] Environment bootstrap completed successfully.")
        return True

    async def _run_pacman(self, args: List[str], callback) -> bool:
        # Needs sudo
        cmd = ["sudo", "pacman"] + args
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT
        )
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
            clone = await asyncio.create_subprocess_exec(
                "git", "clone", "https://aur.archlinux.org/yay-bin.git", tmpdir,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT
            )
            await clone.wait()
            if clone.returncode != 0:
                if callback: await callback("[ERROR] Failed to clone yay repository.")
                return False

            if callback: await callback("[INFO] Building yay package...")
            # makepkg cannot be run as root
            makepkg = await asyncio.create_subprocess_exec(
                "makepkg", "-si", "--noconfirm",
                cwd=tmpdir,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT
            )
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
