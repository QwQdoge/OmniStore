import os
import asyncio
import re
from pathlib import Path

import aiohttp

from core.subprocess_utils import safe_subprocess


class AppImageDownloader:
    def __init__(self, executor):
        self.executor = executor
        self.apps_dir = Path.home() / "Applications"
        self.desktop_dir = Path.home() / ".local/share/applications"
        self.current_download_task = None
        self.timeout = aiohttp.ClientTimeout(total=5)

    async def install(self, package_data: dict, callback=None):
        name = str(package_data.get("name") or "").strip()
        url = package_data.get("url")

        if not url or not name:
            if callback:
                await callback("[ERROR] Invalid package data")
            return False

        safe_name = re.sub(r"[^A-Za-z0-9._-]+", "-", name).strip(".-")
        if not safe_name:
            if callback:
                await callback("[ERROR] Invalid AppImage name")
            return False
        dest_path = self.apps_dir / f"{safe_name}.AppImage"
        part_path = dest_path.with_suffix(".AppImage.part")
        self.apps_dir.mkdir(parents=True, exist_ok=True)

        # Try to get content-length to show progress percentage
        total_size = 0
        try:
            async with aiohttp.ClientSession(timeout=self.timeout) as session:
                async with session.head(url, allow_redirects=True) as resp:
                    if resp.status == 200:
                        total_size = int(resp.headers.get("Content-Length", 0))
        except Exception:
            pass

        # Start wget download
        cmd = ["wget", "-q", "-O", str(part_path), str(url)]
        
        try:
            async with safe_subprocess(
                *cmd,
                env=os.environ.copy()
            ) as self.current_download_task:
                process = self.current_download_task
                last_percent = -1

                # 3. Poll disk file size
                while process.returncode is None:
                    if part_path.exists():
                        current_size = part_path.stat().st_size
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
                    part_path.replace(dest_path)
                    dest_path.chmod(0o755)
                    if callback:
                        await callback("[PROGRESS] 100")
                    return True
                else:
                    part_path.unlink(missing_ok=True)
                    if callback:
                        await callback(f"[ERROR] Download failed (Code: {ret_code})")
                    return False

        except Exception as e:
            part_path.unlink(missing_ok=True)
            if callback:
                await callback(f"[ERROR] AppImage install failed: {e}")

        return False

async def uninstall_appimage(package, callback=None):
    name = str(package.get("name") or "").strip()
    if not name:
        return False
    safe_name = re.sub(r"[^A-Za-z0-9._-]+", "-", name).strip(".-")
    target_path = Path.home() / "Applications" / f"{safe_name}.AppImage"

    if target_path.exists():
        target_path.unlink()
        if callback:
            await callback(f"[INFO] Removed {target_path}")
        return True
    return False
