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
        
    apps_dir = os.path.expanduser("~/Applications")
    os.makedirs(apps_dir, exist_ok=True)

    filename = url.split("/")[-1]
    target_path = os.path.join(apps_dir, filename)

    if callback:
        await callback(f"[INFO] Downloading to {target_path}")

    try:
        async with safe_subprocess(
            "curl", "-L", url, "-o", target_path,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT
        ) as proc:
            if proc.stdout:
                while True:
                    line = await proc.stdout.readline()
                    if not line: break
                    if callback: await callback(f"[INFO] {line.decode().strip()}")
            await proc.wait()
            
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
