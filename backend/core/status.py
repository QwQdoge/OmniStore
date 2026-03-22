import os
import asyncio

class StatusChecker:
    @staticmethod
    async def is_aur_installed(name: str) -> bool:
        """检查 Arch 仓库或 AUR 软件是否安装"""
        # 使用 pacman -Qq (Quiet Query) 检查，如果返回码为 0 则已安装
        proc = await asyncio.create_subprocess_exec(
            "pacman", "-Qq", name,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL
        )
        await proc.wait()
        return proc.returncode == 0

    @staticmethod
    async def is_flatpak_installed(app_id: str) -> bool:
        """检查 Flatpak 是否安装"""
        # flatpak info 只要能查到信息就说明已安装
        proc = await asyncio.create_subprocess_exec(
            "flatpak", "info", "--user", app_id,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL
        )
        await proc.wait()
        return proc.returncode == 0

    @staticmethod
    def is_appimage_installed(name: str) -> bool:
        """检查本地 AppImage 文件是否存在"""
        path = os.path.expanduser(f"~/Applications/{name}.AppImage")
        return os.path.exists(path)

    @classmethod
    async def check(cls, name: str, source: str) -> bool:
        """统一入口"""
        if source == "AUR":
            return await cls.is_aur_installed(name)
        elif source == "Flatpak":
            return await cls.is_flatpak_installed(name)
        elif source == "AppImage":
            return cls.is_appimage_installed(name)
        return False