import os
import time
import asyncio
import sys
from typing import Optional, Callable, Awaitable

class PrivilegeManager:
    """Handles cross-platform privilege escalation (sudo ASKPASS)."""

    def __init__(self):
        self._last_auth_time = 0
        self._auth_timeout = 15 * 60  # 15 minutes

    def _is_auth_cached(self) -> bool:
        return (time.time() - self._last_auth_time) < self._auth_timeout

    async def ensure_privileged(self, callback: Optional[Callable[[str], Awaitable[None]]] = None) -> bool:
        """Acquire sudo privileges safely without a TTY."""
        # Check if we are already root
        if os.getuid() == 0:
            return True

        # 1. Silent check with timeout
        try:
            check = await asyncio.create_subprocess_exec(
                "sudo", "-n", "true",
                stderr=asyncio.subprocess.DEVNULL,
                stdout=asyncio.subprocess.DEVNULL,
            )
            await asyncio.wait_for(check.wait(), timeout=5)
            if check.returncode == 0:
                self._last_auth_time = time.time()
                return True
        except (asyncio.TimeoutError, Exception):
            pass

        # 2. Memory cache
        if self._is_auth_cached():
            return True

        # 3. GUI askpass
        if callback:
            await callback("[INFO] Requesting administrator password (a dialog will appear)...")

        try:
            askpass_tool = await self._find_askpass()
            if not askpass_tool:
                if callback:
                    await callback("[ERROR] No graphical askpass tool found (zenity/ksshaskpass). Please install zenity or run with sudo.")
                return False

            try:
                password = await asyncio.wait_for(self._run_askpass(askpass_tool), timeout=60)
            except asyncio.TimeoutError:
                if callback: await callback("[ERROR] Password request timed out.")
                return False

            if password is None:
                if callback: await callback("[ERROR] Password dialog was cancelled.")
                return False

            env = os.environ.copy()
            env.pop("TERM", None)
            # Ensure DISPLAY is set for GUI tools if possible
            if "DISPLAY" not in env:
                env["DISPLAY"] = ":0"

            sudo_proc = await asyncio.create_subprocess_exec(
                "sudo", "-S", "-p", "", "-v",
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.PIPE,
                env=env,
            )

            password_bytes = (password + "\n").encode("utf-8")
            try:
                _, stderr_bytes = await asyncio.wait_for(sudo_proc.communicate(input=password_bytes), timeout=15)
            except asyncio.TimeoutError:
                if sudo_proc.returncode is None:
                    try: sudo_proc.kill()
                    except: pass
                if callback: await callback("[ERROR] Sudo verification timed out.")
                return False

            if sudo_proc.returncode == 0:
                self._last_auth_time = time.time()
                if callback: await callback("[INFO] Authorization confirmed.")
                return True

            if callback:
                err_msg = stderr_bytes.decode("utf-8", errors="replace").strip()
                await callback(f"[ERROR] Authorization failed: {err_msg or 'Incorrect password'}")
            return False

        except Exception as e:
            if callback: await callback(f"[ERROR] Auth system error: {e}")
            return False

    async def _find_askpass(self) -> Optional[str]:
        desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").upper()
        if "KDE" in desktop:
            preferred_order = ("ksshaskpass", "zenity")
        else:
            preferred_order = ("zenity", "ksshaskpass")

        for prog in preferred_order:
            which = await asyncio.create_subprocess_exec("which", prog, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
            stdout, _ = await which.communicate()
            if which.returncode == 0:
                return stdout.decode().strip()
        return None

    async def _run_askpass(self, tool: str) -> Optional[str]:
        tool_name = os.path.basename(tool)
        if tool_name == "zenity":
            cmd = [tool, "--password"]
        else:
            cmd = [tool, "Omnistore Needs Privileges\nPlease enter password:"]

        proc = await asyncio.create_subprocess_exec(*cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
        stdout, _ = await proc.communicate()
        if proc.returncode != 0: return None
        return stdout.decode("utf-8", errors="replace").rstrip("\n") or None
