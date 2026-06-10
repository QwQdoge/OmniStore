import os
import asyncio
from core.subprocess_utils import safe_subprocess

async def install_appimage(package, callback=None):
    if callback:
        await callback(f"[INFO] Installing AppImage: {package.get('name')}")

    url = package.get("url")
    if not url:
        if callback:
            await callback("[ERROR] No URL provided for AppImage install")
        return False
        
        try:
            async with safe_subprocess(
                *cmd,
                env=os.environ.copy()
            ) as self.current_download_task:
                process = self.current_download_task
                last_percent = -1

                # 3. Poll disk file size
                while process.returncode is None:
                    if dest_path.exists():
                        current_size = dest_path.stat().st_size
                        if total_size > 0:
                            percent = int((current_size / total_size) * 100)
                            if percent > last_percent and percent < 100:
                                if callback:
                                    await callback(f"[PROGRESS] {percent}")
                                last_percent = percent
                        else:
                            mb = current_size // (1024 * 1024)
                            if mb > last_percent:
                                if callback:
                                    await callback(f"[INFO] Downloaded: {mb}MB")
                                last_percent = mb

                    if process.returncode is not None:
                        break
                    await asyncio.sleep(1)

                ret_code = await process.wait()

                if ret_code == 0:
                    dest_path.chmod(0o755)
                    self._create_desktop_entry(name, dest_path)
                    if callback:
                        await callback("[PROGRESS] 100")
                else:
                    if callback:
                        await callback(f"[ERROR] Download failed (Code: {ret_code})")

        except Exception as e:
            if callback:
                await callback(f"[ERROR] Exception: {e}")
        finally:
            self.current_download_task = None

    async def uninstall(self, package_data: dict, callback=None):
        """Unified uninstallation interface"""
        name = package_data.get("name")
        if not name:
            return

        desktop_file = self.desktop_dir / f"{name.lower()}.desktop"
        appimage_path = None

        try:
            # 1. Try to read actual path from .desktop file
            if desktop_file.exists():
                with open(desktop_file, "r") as f:
                    for line in f:
                        if line.startswith("Exec="):
                            path_str = line.split("Exec=")[1].split("%U")[0].strip().strip('"\'')
                            if path_str:
                                appimage_path = Path(path_str)
                            break
            
        if os.path.exists(target_path):
            os.chmod(target_path, 0o755)
            if callback:
                await callback("[PROGRESS] 100")
            return True
    except Exception as e:
        if callback:
            await callback(f"[ERROR] AppImage install failed: {e}")

    return False

async def uninstall_appimage(package, callback=None):
    url = package.get("url")
    if not url: return False

    filename = url.split("/")[-1]
    target_path = os.path.expanduser(f"~/Applications/{filename}")

    if os.path.exists(target_path):
        os.remove(target_path)
        if callback:
            await callback(f"[INFO] Removed {target_path}")
        return True
    return False
