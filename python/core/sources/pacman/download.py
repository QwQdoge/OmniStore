import asyncio
import re
from core.subprocess_utils import safe_subprocess
from typing import Dict, Any, Callable
from core.sources.utils import PrivilegeManager
from core.subprocess_utils import safe_subprocess

privilege = PrivilegeManager()

async def install_pacman(package: Dict[str, Any], callback: Callable = None) -> bool:
    if not await privilege.ensure_privileged(callback):
        return False

    name = package.get("name")
    if callback:
        await callback(f"[INFO] Running: sudo pacman -S --noconfirm {name}")

    try:
        async with safe_subprocess(
            "sudo", "pacman", "-S", "--noconfirm", name,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT
        ) as proc:

        last_sent_progress = -1
        if proc.stdout:
            while True:
                line_bytes = await proc.stdout.readline()
                if not line_bytes:
                    break
                line = line_bytes.decode('utf-8', errors='ignore').strip()
                if not line:
                    continue
                if callback:
                    await callback(f"[INFO] {line}")
<<<<<<< HEAD
                    
                    # Parse pacman download progress & speed
                    progress_match = re.search(r"(\d+)%", line)
                    speed_match = re.search(r"(\d+(\.\d+)?\s*(k|M|G)?i?B/s)", line)
                    
=======

                    # Parse pacman download progress & speed
                    progress_match = re.search(r"(\d+)%", line)
                    speed_match = re.search(r"(\d+(\.\d+)?\s*(k|M|G)?i?B/s)", line)

>>>>>>> 0a17cab997c6763e54edc6d7310373d52334eb62
                    if progress_match:
                        percent = int(progress_match.group(1))
                        if percent > last_sent_progress:
                            await callback(f"[PROGRESS] {percent}")
                            last_sent_progress = percent
<<<<<<< HEAD
                    
=======

>>>>>>> 0a17cab997c6763e54edc6d7310373d52334eb62
                    if speed_match:
                        await callback(f"[SPEED] {speed_match.group(1)}")

        await proc.wait()
        if proc.returncode == 0 and callback:
            await callback("[PROGRESS] 100")
        return proc.returncode == 0

async def uninstall_pacman(package: Dict[str, Any], callback: Callable = None) -> bool:
    if not await privilege.ensure_privileged(callback):
        return False

    name = package.get("name")
    if callback:
        await callback(f"[INFO] Running: sudo pacman -Rs --noconfirm {name}")

    try:
        async with safe_subprocess(
            "sudo", "pacman", "-Rs", "--noconfirm", name,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT
        ) as proc:

        if proc.stdout:
            while True:
                line_bytes = await proc.stdout.readline()
                if not line_bytes:
                    break
                line = line_bytes.decode('utf-8', errors='ignore').strip()
                if not line:
                    continue
                if callback:
                    await callback(f"[INFO] {line}")

        await proc.wait()
        if proc.returncode == 0 and callback:
            await callback("[PROGRESS] 100")
        return proc.returncode == 0
