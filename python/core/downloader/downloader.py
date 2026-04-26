import os
import time
from .yay import YayDownloader
from .Appimage import AppImageDownloader
from .flatpak import FlatpakDownloader  # 导入你写好的类
import asyncio


class InstallExecutor:
    def __init__(self):
        # 初始化所有子下载器
        self.yay = YayDownloader(self)  # 传递 InstallExecutor 实例给 YayDownloader
        self.appimage = AppImageDownloader(self)  # 同样传递给 AppImageDownloader
        self.flatpak = FlatpakDownloader(self)  # 同样传递给 FlatpakDownloader

        # 状态锁：防止多个任务同时运行导致系统锁死
        self.is_running = False
        self.current_process = None  # 用于跟踪当前的子进程，方便实现停止功能

        # 授权管理
        self._last_auth_time = 0
        self._auth_timeout = 15 * 60  # 15分钟授权有效期

    async def _ensure_privileged(self, callback=None):
        env = os.environ.copy()
        env["DISPLAY"] = os.environ.get("DISPLAY", ":0")

        # 1. Silent check: if already has sudo permission
        check = await asyncio.create_subprocess_exec(
            "sudo", "-n", "true",
            stderr=asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.DEVNULL
        )
        await check.wait()
        if check.returncode == 0:
            return True

        try:
            if callback:
                await callback("[INFO] Requesting system authorization...")

            # 2. Call pkexec popup
            auth_proc = await asyncio.create_subprocess_exec(
                "pkexec", "sudo", "-v",
                env=env,
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL
            )

            await auth_proc.wait()
            ret_code = auth_proc.returncode

            if ret_code == 0:
                self._last_auth_time = time.time()
                if callback:
                    await callback("[INFO] Authorization confirmed.")
                return True

            if callback:
                await callback("[ERROR] Authorization failed: User cancelled or incorrect password.")
            return False

        except Exception as e:
            if callback:
                await callback(f"[ERROR] Auth system error: {e}")
            return False

    async def install(self, package: dict, callback):
        """Unified installation entry"""
        if self.is_running:
            if callback:
                await callback("[ERROR] Another installation is already in progress.")
            return

        source = package.get("source")
        name = package.get("name")

        if not name:
            if callback:
                await callback("[ERROR] Package name is missing.")
            return

        try:
            self.is_running = True
            # AppImage and Flatpak (--user) don't need privileges
            if source not in ["AppImage", "Flatpak"]:
                if not await self._ensure_privileged(callback):
                    return

            if callback:
                await callback(f"[INFO] Starting {source} installation for {name}...")

            if source in ["AUR", "Pacman"]:
                await self.yay.install(name, callback=callback)

            elif source == "Flatpak":
                await self.flatpak.install(name, callback=callback)

            elif source == "AppImage":
                await self.appimage.install(package, callback=callback)

            else:
                if callback:
                    await callback(f"[ERROR] Unsupported source: {source}")

        except Exception as e:
            if callback:
                await callback(f"[ERROR] Executor failed: {e}")
        finally:
            self.is_running = False

    async def uninstall(self, package: dict, callback=None):
        """Unified uninstallation entry"""
        if self.is_running:
            if callback:
                await callback("[ERROR] System is busy, please wait.")
            return

        source = package.get("source")
        name = package.get("name")
        if not name:
            return

        try:
            self.is_running = True

            # 1. Elevate privileges
            if not await self._ensure_privileged(callback):
                return

            if callback:
                await callback(f"[INFO] Removing {name} from {source}...")

            # 2. Dispatch to specific downloader
            if source == "AUR":
                await self.yay.uninstall(name, callback=callback)
            elif source == "Flatpak":
                await self.flatpak.uninstall(name, callback=callback)
            elif source == "AppImage":
                await self.appimage.uninstall(package, callback=callback)

        except Exception as e:
            if callback:
                await callback(f"[ERROR] Uninstall failed: {e}")
        finally:
            self.is_running = False

    def stop(self):
        """Emergency stop"""
        self.yay.stop()
        # self.appimage.stop()
        # self.flatpak.stop()
        self.is_running = False
        return "All stop signals sent."
