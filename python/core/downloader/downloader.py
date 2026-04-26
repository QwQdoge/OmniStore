import os
import time
import asyncio
from .yay import YayDownloader
from .Appimage import AppImageDownloader
from .flatpak import FlatpakDownloader


class InstallExecutor:
    def __init__(self):
        self.yay = YayDownloader(self)
        self.appimage = AppImageDownloader(self)
        self.flatpak = FlatpakDownloader(self)

        self.is_running = False
        self.current_process = None

        self._last_auth_time = 0
        self._auth_timeout = 15 * 60  # 15 minutes

    def _is_auth_cached(self) -> bool:
        """Check if we have a recent successful auth within the timeout window."""
        return (time.time() - self._last_auth_time) < self._auth_timeout

    async def _ensure_privileged(self, callback=None) -> bool:
        """
        Acquire sudo privileges safely without a TTY.

        Strategy (in order):
        1. Silent check: 'sudo -n true' — succeeds if there's an active session.
        2. Internal cache: if we authenticated recently, skip re-prompting.
        3. Graphical askpass: use zenity/ksshaskpass to get the password from
           the user via a GUI dialog, then feed it to 'sudo -S -v'.
           The password is passed through a pipe (never via env var or argv).

        SECURITY NOTES:
        - Password is never stored in memory beyond the subprocess call.
        - We do NOT use pkexec + sudo (double escalation).
        - We do NOT use 'sudo -e' with env var injection.
        - The pipe is closed immediately after sudo reads it.
        """
        # 1. Silent non-interactive check
        check = await asyncio.create_subprocess_exec(
            "sudo", "-n", "true",
            stderr=asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.DEVNULL,
        )
        await check.wait()
        if check.returncode == 0:
            self._last_auth_time = time.time()
            return True

        # 2. Memory cache (avoids re-prompting within the session)
        if self._is_auth_cached():
            return True

        # 3. GUI password prompt via zenity or ksshaskpass
        if callback:
            await callback("[INFO] Requesting administrator password (a dialog will appear)...")

        try:
            askpass_tool = await self._find_askpass()
            if not askpass_tool:
                if callback:
                    await callback("[ERROR] No graphical askpass tool found (tried: zenity, ksshaskpass). "
                                   "Please install 'zenity' or configure SUDO_ASKPASS.")
                return False

            password = await self._run_askpass(askpass_tool)
            if password is None:
                if callback:
                    await callback("[ERROR] Password dialog was cancelled.")
                return False

            # Feed password to sudo via stdin pipe — never via env or args
            env = os.environ.copy()
            # Prevent sudo from trying to read from a (non-existent) terminal
            env.pop("TERM", None)

            sudo_proc = await asyncio.create_subprocess_exec(
                "sudo", "-S", "-v",
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
                env=env,
            )

            # Write password followed by newline, then close stdin
            password_bytes = (password + "\n").encode("utf-8")
            await sudo_proc.communicate(input=password_bytes)

            # Immediately zero out the password string (best-effort in Python)
            password = "\x00" * len(password)
            del password

            if sudo_proc.returncode == 0:
                self._last_auth_time = time.time()
                if callback:
                    await callback("[INFO] Authorization confirmed.")
                return True

            if callback:
                await callback("[ERROR] Incorrect password or authorization was denied.")
            return False

        except Exception as e:
            if callback:
                await callback(f"[ERROR] Auth system error: {e}")
            return False

    async def _find_askpass(self) -> str | None:
        """Find a usable graphical askpass program.
        
        On KDE, ksshaskpass is native and reliable.
        On GNOME/other, zenity (GTK) works well.
        Fallback: check SUDO_ASKPASS / SSH_ASKPASS env vars.
        """
        # 1. Honour explicit user/system configuration
        configured = os.environ.get("SUDO_ASKPASS") or os.environ.get("SSH_ASKPASS")
        if configured and os.path.isfile(configured):
            return configured

        # 2. Detect desktop environment and pick the native tool first
        desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").upper()
        kde_session = os.environ.get("KDE_FULL_SESSION", "")

        if kde_session or "KDE" in desktop:
            # KDE: prefer ksshaskpass (Qt-native, works on Wayland)
            preferred_order = ("ksshaskpass", "zenity", "ssh-askpass", "x11-ssh-askpass")
        elif "GNOME" in desktop:
            # GNOME: prefer zenity (GTK-native)
            preferred_order = ("zenity", "ssh-askpass", "ksshaskpass", "x11-ssh-askpass")
        else:
            preferred_order = ("zenity", "ksshaskpass", "ssh-askpass", "x11-ssh-askpass")

        for prog in preferred_order:
            which = await asyncio.create_subprocess_exec(
                "which", prog,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
            )
            stdout, _ = await which.communicate()
            if which.returncode == 0:
                return stdout.decode().strip()

        return None

    async def _run_askpass(self, tool: str) -> str | None:
        """
        Run the askpass GUI and return the password string, or None if cancelled.

        - ksshaskpass / ssh-askpass style: prompt string as first positional arg
        - zenity: --password flag only (--title/--text not supported in password mode)
        """
        tool_name = os.path.basename(tool)

        env = os.environ.copy()
        env["DISPLAY"] = os.environ.get("DISPLAY", ":0")
        env["WAYLAND_DISPLAY"] = os.environ.get("WAYLAND_DISPLAY", "")
        env["LC_ALL"] = "C.UTF-8"  # suppress Qt locale warnings from ksshaskpass

        if tool_name == "zenity":
            # zenity 4.x password mode: only --password is supported (no --title/--text)
            cmd = [tool, "--password"]
        else:
            # ksshaskpass / ssh-askpass: prompt as positional arg
            cmd = [tool, "Omnistore 需要管理员权限\n请输入您的用户密码："]

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,  # suppress GTK/Qt locale warnings
            env=env,
        )
        stdout, _ = await proc.communicate()

        if proc.returncode != 0:
            return None  # User cancelled

        password = stdout.decode("utf-8", errors="replace").rstrip("\n")
        return password if password else None

    def _needs_privilege(self, source: str) -> bool:
        """
        Return True only for sources that genuinely need elevated privileges.
        Flatpak (--user) and AppImage (~/) operate entirely in user space.
        """
        return source not in ("AppImage", "Flatpak")

    async def install(self, package: dict, callback):
        """Unified installation entry"""
        if self.is_running:
            if callback:
                await callback("[ERROR] Another installation is already in progress.")
            return False

        source = package.get("source")
        name = package.get("name")

        if not name:
            if callback:
                await callback("[ERROR] Package name is missing.")
            return False

        try:
            self.is_running = True

            if self._needs_privilege(source):
                if not await self._ensure_privileged(callback):
                    return False

            if callback:
                await callback(f"[INFO] Starting {source} installation for {name}...")

            if source in ("AUR", "Pacman", "Native"):
                return await self.yay.install(name, callback=callback)
            elif source == "Flatpak":
                return await self.flatpak.install(name, callback=callback)
            elif source == "AppImage":
                return await self.appimage.install(package, callback=callback)
            else:
                if callback:
                    await callback(f"[ERROR] Unsupported source: {source}")
                return False

        except Exception as e:
            if callback:
                await callback(f"[ERROR] Executor failed: {e}")
            return False
        finally:
            self.is_running = False

    async def uninstall(self, package: dict, callback=None):
        """Unified uninstallation entry"""
        if self.is_running:
            if callback:
                await callback("[ERROR] System is busy, please wait.")
            return False

        source = package.get("source")
        name = package.get("name")
        if not name:
            return False

        try:
            self.is_running = True

            if self._needs_privilege(source):
                if not await self._ensure_privileged(callback):
                    return False

            if callback:
                await callback(f"[INFO] Removing {name} from {source}...")

            if source in ("AUR", "Native"):
                return await self.yay.uninstall(name, callback=callback)
            elif source == "Flatpak":
                return await self.flatpak.uninstall(name, callback=callback)
            elif source == "AppImage":
                return await self.appimage.uninstall(package, callback=callback)
            else:
                if callback:
                    await callback(f"[ERROR] Unsupported source for uninstall: {source}")
                return False

        except Exception as e:
            if callback:
                await callback(f"[ERROR] Uninstall failed: {e}")
            return False
        finally:
            self.is_running = False

    def stop(self):
        """Emergency stop"""
        self.yay.stop()
        self.appimage.stop()
        self.flatpak.stop()
        self.is_running = False
        return "All stop signals sent."
