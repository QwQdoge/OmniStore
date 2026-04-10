import os
import time
from .yay import YayDownloader
from .Appimage import AppImageDownloader
from .flatpak import FlatpakDownloader  # 导入你写好的类
import asyncio
import sys

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
        
        # 1. 静默检查：如果已经有 sudo 权限了，直接过
        check = await asyncio.create_subprocess_exec(
            "sudo", "-n", "true", 
            stderr=asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.DEVNULL
        )
        await check.wait()
        if check.returncode == 0:
            return True

        try:
            if callback: await callback("[Status] Requesting system authorization...")
            
            # 2. 调用 pkexec 弹窗
            auth_proc = await asyncio.create_subprocess_exec(
                "pkexec", "sudo", "-v",
                env=env,
                stdout=asyncio.subprocess.DEVNULL, # 不再捕获输出，减少干扰
                stderr=asyncio.subprocess.DEVNULL  # 屏蔽掉那个 "password is required" 的垃圾信息
            )
            
            # 等待弹窗结束
            await auth_proc.wait()
            ret_code = auth_proc.returncode

            # 🌟 核心逻辑：只要 pkexec 返回 0，代表用户在 GUI 输对了密码
            if ret_code == 0:
                self._last_auth_time = time.time()
                # 我们不再运行 sudo -n true 去自讨没趣，直接信任 pkexec
                if callback: await callback("[Status] Authorization confirmed.")
                return True
            
            if callback: await callback(f"Authorization failed: User cancelled or incorrect password.")
            return False
                
        except Exception as e:
            if callback: await callback(f"Auth system error: {e}")
            return False

    async def install(self, package: dict, callback):
        """统一安装入口"""
        if self.is_running:
            if callback: await callback("[Error] Another installation is already in progress.")
            return
        
        source = package.get("source")
        name = package.get("name")
        
        if not name:
            if callback: await callback("[Error] Package name is missing.")
            return
            
        
        try:
            self.is_running = True
            if not await self._ensure_privileged(callback):
                return
            
            if callback: await callback(f"[Executor] Starting {source} installation for {name}...")

            if source in ["AUR", "Pacman"]:
                # AUR 只需传名称
                await self.yay.install(name, callback=callback)
            
            elif source == "Flatpak":
                # Flatpak 也只需传名称 (AppID)
                await self.flatpak.install(name, callback=callback)
                
            elif source == "AppImage":
                # AppImage 需要整个 package 字典（因为有 URL）
                await self.appimage.install(package, callback=callback)
            
            else:
                if callback: await callback(f"[Error] Unsupported source: {source}")

        except Exception as e:
            if callback: await callback(f"[Error] Executor failed: {e}")
        finally:
            self.is_running = False

    async def uninstall(self, package: dict, callback=None):
        """统一卸载入口"""
        if self.is_running:
            if callback: await callback("[Error] System is busy, please wait.")
            return

        source = package.get("source")
        name = package.get("name")
        if not name: return

        try:
            self.is_running = True
            
            # 🌟 第一步：先进行 GUI + sudo 提权（两边都顾到）
            if not await self._ensure_privileged(callback):
                return # 授权失败直接返回，finally 会释放锁

            if callback: await callback(f"[Executor] Removing {name} from {source}...")

            # 🌟 第二步：分发给具体的下载器去干活
            if source == "AUR":
                await self.yay.uninstall(name, callback=callback)
            elif source == "Flatpak":
                await self.flatpak.uninstall(name, callback=callback)
            elif source == "AppImage":
                await self.appimage.uninstall(package, callback=callback)

        except Exception as e:
            if callback: await callback(f"[Error] Uninstall failed: {e}")
        finally:
            self.is_running = False # 🌟 确保无论如何都会解锁

    def stop(self):
        """一键急停"""
        # 遍历所有下载器执行停止逻辑
        self.yay.stop()
        # self.appimage.stop()
        # self.flatpak.stop()
        self.is_running = False
        return "All stop signals sent."