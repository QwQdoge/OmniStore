import asyncio
from core.subprocess_utils import safe_subprocess
from typing import Dict, Any, Callable
from core.sources.utils import PrivilegeManager

privilege = PrivilegeManager()

async def install_pacman(package: Dict[str, Any], callback: Callable = None) -> bool:
    if not await privilege.ensure_privileged(callback):
        return False

    name = package.get("name")
    if callback:
        await callback(f"[INFO] Running: sudo pacman -S --noconfirm {name}")

    async with safe_subprocess(
        "sudo", "pacman", "-S", "--noconfirm", name,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT
    ) as proc:

        if proc.stdout:
            while True:
                line = await proc.stdout.readline()
                if not line:
                    break
                if callback:
                    await callback(line.decode().strip())

        await proc.wait()
        return proc.returncode == 0

async def uninstall_pacman(package: Dict[str, Any], callback: Callable = None) -> bool:
    if not await privilege.ensure_privileged(callback):
        return False

    name = package.get("name")
    if callback:
        await callback(f"[INFO] Running: sudo pacman -Rs --noconfirm {name}")

    async with safe_subprocess(
        "sudo", "pacman", "-Rs", "--noconfirm", name,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT
    ) as proc:

        if proc.stdout:
            while True:
                line = await proc.stdout.readline()
                if not line:
                    break
                if callback:
                    await callback(line.decode().strip())

        await proc.wait()
        return proc.returncode == 0
