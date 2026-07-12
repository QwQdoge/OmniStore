import os
import time
import asyncio
from core.subprocess_utils import safe_subprocess
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
        check = None
        try:
            async with safe_subprocess(
                "sudo", "-n", "true",
                stderr=asyncio.subprocess.DEVNULL,
                stdout=asyncio.subprocess.DEVNULL,
            ) as check:
                await asyncio.wait_for(check.wait(), timeout=5)
                if check.returncode == 0:
                    self._last_auth_time = time.time()
                    return True
        except (asyncio.TimeoutError, Exception):
            pass
        finally:
            if check and check.returncode is None:
                try:
                    check.kill()
                    await check.wait()
                except Exception:
                    pass

        # 2. Memory cache
        if self._is_auth_cached():
            return True

        # 3. GUI askpass
        if callback:
            await callback("[INFO] Requesting administrator password (a dialog will appear)...")

        try:
            askpass_tool = await asyncio.wait_for(self._find_askpass(), timeout=5)
            if not askpass_tool:
                if callback:
                    await callback("[ERROR] No graphical askpass tool found (zenity/ksshaskpass). Please install zenity or run with sudo.")
                return False

            try:
                # Security: password entry must have a strict timeout
                password = await asyncio.wait_for(self._run_askpass(askpass_tool), timeout=60)
            except asyncio.TimeoutError:
                if callback: await callback("[ERROR] Password request timed out.")
                return False
            except Exception as e:
                if callback: await callback(f"[ERROR] Askpass tool failed: {e}")
                return False

            if password is None:
                if callback: await callback("[ERROR] Password dialog was cancelled.")
                return False

            env = os.environ.copy()
            env.pop("TERM", None)
            # Ensure DISPLAY is set for GUI tools if possible
            if "DISPLAY" not in env:
                env["DISPLAY"] = ":0"

            sudo_proc = None
            try:
                async with safe_subprocess(
                    "sudo", "-S", "-p", "", "-v",
                    stdin=asyncio.subprocess.PIPE,
                    stdout=asyncio.subprocess.DEVNULL,
                    stderr=asyncio.subprocess.PIPE,
                    env=env,
                ) as sudo_proc:

                    password_bytes = (password + "\n").encode("utf-8")
                    # Absolute safety: Never wait indefinitely for sudo
                    _, stderr_bytes = await asyncio.wait_for(sudo_proc.communicate(input=password_bytes), timeout=15)
            except asyncio.TimeoutError:
                if sudo_proc and sudo_proc.returncode is None:
                    try:
                        sudo_proc.kill()
                        await sudo_proc.wait()
                    except Exception: pass
                if callback: await callback("[ERROR] Sudo verification timed out.")
                return False
            finally:
                # Clear password from memory immediately
                password = None
                password_bytes = None

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

        # Boundary Defense: Don't spend too much time looking for tools
        for prog in preferred_order:
            which = None
            try:
                async with safe_subprocess("which", prog, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as which:
                    stdout, _ = await asyncio.wait_for(which.communicate(), timeout=2)
                    if which.returncode == 0:
                        return stdout.decode().strip()
            except Exception:
                continue
            finally:
                if which and which.returncode is None:
                    try:
                        which.kill()
                        await which.wait()
                    except Exception:
                        pass
        return None

    async def _run_askpass(self, tool: str) -> Optional[str]:
        tool_name = os.path.basename(tool)
        if tool_name == "zenity":
            cmd = [tool, "--password"]
        else:
            cmd = [tool, "Omnistore Needs Privileges\nPlease enter password:"]

        proc = None
        try:
            async with safe_subprocess(*cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                stdout, _ = await proc.communicate()
                if proc.returncode != 0: return None
                return stdout.decode("utf-8", errors="replace").rstrip("\n") or None
        finally:
            if proc and proc.returncode is None:
                try:
                    proc.kill()
                    await proc.wait()
                except Exception:
                    pass
