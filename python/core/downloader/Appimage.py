import os
import aiohttp
import asyncio
from pathlib import Path


class AppImageDownloader:
    def __init__(self, executor):
        self.executor = executor
        self.apps_dir = Path.home() / "Applications"
        self.desktop_dir = Path.home() / ".local/share/applications"
        self.current_download_task = None
        self.timeout = aiohttp.ClientTimeout(total=5)

    async def install(self, package_data: dict, callback=None):
        name = package_data.get("name")
        url = package_data.get("url")
        dest_path = self.apps_dir / f"{name}.AppImage"
        self.apps_dir.mkdir(parents=True, exist_ok=True)

        if not url or not name:
            if callback:
                await callback("[ERROR] Invalid package data")
            return

        # Start wget download
        cmd = ["wget", "-q", "-O", str(dest_path), str(url)]
        
        try:
            self.current_download_task = await asyncio.create_subprocess_exec(
                *cmd,
                env=os.environ.copy()
            )
            process = self.current_download_task
            total_size = 0  # Initial 0
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
            
            # 2. Fuzzy match by name if not found
            if not appimage_path or not appimage_path.exists():
                for f in self.apps_dir.glob("*.AppImage"):
                    if name.lower() in f.name.lower():
                        appimage_path = f
                        break
            
            # 3. Fallback to default path
            if not appimage_path:
                appimage_path = self.apps_dir / f"{name}.AppImage"

            # Delete binary
            if appimage_path.exists():
                appimage_path.unlink()
                if callback:
                    await callback(f"[INFO] Removed binary: {appimage_path}")

            # Delete menu entry
            if desktop_file.exists():
                desktop_file.unlink()
                if callback:
                    await callback(f"[INFO] Removed menu entry: {desktop_file}")

            msg = f"[INFO] Success: {name} uninstalled"
            if callback:
                await callback(msg)
            print(msg)

        except Exception as e:
            err = f"[ERROR] Uninstall Error: {e}"
            if callback:
                await callback(err)
            print(err)

    def _create_desktop_entry(self, name: str, exec_path: Path):
        """Generate .desktop file"""
        desktop_file = self.desktop_dir / f"{name.lower()}.desktop"
        content = f"""[Desktop Entry]
Version=1.0
Type=Application
Name={name}
Comment=Installed via Omnistore
Exec="{exec_path}" %U
Icon={name.lower()}
Terminal=false
Categories=Utility;Application;
"""
        with open(desktop_file, "w") as f:
            f.write(content)

    def stop(self):
        """Stop current download task"""
        if self.current_download_task and self.current_download_task.returncode is None:
            try:
                self.current_download_task.terminate()
            except Exception:
                pass
