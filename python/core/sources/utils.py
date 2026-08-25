import os
import asyncio
from core.subprocess_utils import safe_subprocess
import sys
from typing import Optional, Callable, Awaitable

class PrivilegeManager:
    """Handles cross-platform privilege escalation (sudo ASKPASS)."""

    def __init__(self):
        self._askpass_tool: Optional[str] = None

    async def subprocess_environment(self) -> dict[str, str]:
        """Return an environment suitable for an explicit ``sudo -A`` call.

        The helper path is not a credential. Keeping it here lets nested tools
        such as yay use the same graphical authorization path as OmniStore.
        """
        askpass_tool = self._askpass_tool or await self._find_askpass()
        if not askpass_tool:
            raise RuntimeError("No sudo-compatible graphical askpass helper found")
        self._askpass_tool = askpass_tool
        env = os.environ.copy()
        env["SUDO_ASKPASS"] = askpass_tool
        return env

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
                    return True
        except (asyncio.TimeoutError, Exception):
            pass

        # 2. GUI askpass. Let sudo invoke the desktop helper directly so the
        # application process never receives or stores the password.
        if callback:
            await callback("[INFO] Requesting administrator password (a dialog will appear)...")

        try:
            askpass_tool = await asyncio.wait_for(self._find_askpass(), timeout=5)
            if not askpass_tool:
                if callback:
                    await callback("[ERROR] No sudo-compatible graphical askpass helper found. Please install ksshaskpass or run OmniStore from an authenticated session.")
                return False

            self._askpass_tool = askpass_tool
            env = await self.subprocess_environment()

            sudo_proc = None
            try:
                async with safe_subprocess(
                    "sudo", "-A", "-p", "OmniStore requires administrator privileges", "-v",
                    stdin=asyncio.subprocess.DEVNULL,
                    stdout=asyncio.subprocess.DEVNULL,
                    stderr=asyncio.subprocess.PIPE,
                    env=env,
                ) as sudo_proc:
                    _, stderr_bytes = await asyncio.wait_for(
                        sudo_proc.communicate(), timeout=60
                    )
            except asyncio.TimeoutError:
                if callback: await callback("[ERROR] Sudo verification timed out.")
                return False
            if sudo_proc.returncode == 0:
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
        preferred_order = ("ksshaskpass", "ssh-askpass", "lxqt-openssh-askpass")

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
        return None
