import asyncio
import re
from core.subprocess_utils import safe_subprocess
from typing import Dict, Any, Callable, Optional
from core.sources.utils import PrivilegeManager

privilege = PrivilegeManager()

async def install_pacman(package: Dict[str, Any], callback: Optional[Callable] = None) -> bool:
    try:
        if not await privilege.ensure_privileged(callback):
            return False

        name = package.get("name")
        if not name:
             if callback: await callback("[ERROR] Package name missing for pacman install.")
             return False

        if callback:
            await callback(f"[INFO] Running: sudo pacman -S --noconfirm {name}")

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

                        # Parse pacman download progress & speed
                        progress_match = re.search(r"(\d+)%", line)
                        speed_match = re.search(r"(\d+(\.\d+)?\s*(k|M|G)?i?B/s)", line)

                        if progress_match:
                            percent = int(progress_match.group(1))
                            if percent > last_sent_progress:
                                await callback(f"[PROGRESS] {percent}")
                                last_sent_progress = percent
                        else:
                            # Pseudo-progress for piped output
                            if "resolving dependencies" in line.lower():
                                await callback("[PROGRESS] 10")
                                last_sent_progress = 10
                            elif "downloading" in line.lower() and last_sent_progress < 30:
                                await callback("[PROGRESS] 30")
                                last_sent_progress = 30
                            elif "installing" in line.lower() and last_sent_progress < 70:
                                await callback("[PROGRESS] 70")
                                last_sent_progress = 70
                            
                            # Use [SPEED] to display the current status text to the user
                            if len(line) > 0 and not line.startswith("("):
                                display_line = line[:40] + "..." if len(line) > 40 else line
                                await callback(f"[SPEED] {display_line}")

                        if speed_match:
                            await callback(f"[SPEED] {speed_match.group(1)}")

            await proc.wait()
            if proc.returncode == 0 and callback:
                await callback("[PROGRESS] 100")
            return proc.returncode == 0
    except Exception as e:
        if callback: await callback(f"[ERROR] Pacman installation failed: {e}")
        return False

async def uninstall_pacman(package: Dict[str, Any], callback: Optional[Callable] = None) -> bool:
    try:
        if not await privilege.ensure_privileged(callback):
            return False

        name = package.get("name")
        if not name:
             if callback: await callback("[ERROR] Package name missing for pacman uninstall.")
             return False

        if callback:
            await callback(f"[INFO] Running: sudo pacman -Rs --noconfirm {name}")

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
                        if "checking dependencies" in line.lower():
                            await callback("[PROGRESS] 20")
                        elif "removing" in line.lower():
                            await callback("[PROGRESS] 50")
                        if len(line) > 0 and not line.startswith("("):
                            display_line = line[:40] + "..." if len(line) > 40 else line
                            await callback(f"[SPEED] {display_line}")

            await proc.wait()
        if proc.returncode == 0 and callback:
            await callback("[PROGRESS] 100")
        return proc.returncode == 0
    except Exception as e:
        if callback: await callback(f"[ERROR] Pacman uninstallation failed: {e}")
        return False
