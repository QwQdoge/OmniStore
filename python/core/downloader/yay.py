import asyncio
import os
import re
from typing import List, Dict, Optional, TYPE_CHECKING, Any

if TYPE_CHECKING:
    pass


class YayDownloader:
    def __init__(self, executor: Any):
        self.current_process = None
        self._current_task = None
        self.executor = executor

    async def _run_command(self, cmd: List[str], env: Optional[Dict[str, str]] = None, callback=None):
        """
        Execute yay/pacman command and stream logs/progress back to callback.
        """
        final_env = os.environ.copy()
        final_env.update({
            "FORCE_COLOR": "1",
            "LC_ALL": "en_US.UTF-8",
            "SUDO_USER": os.getlogin()
        })
        if env:
            final_env.update(env)

        try:
            self.current_process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                env=final_env,
                stdin=asyncio.subprocess.DEVNULL
            )

            if self.current_process.stdout:
                while True:
                    line_bytes = await self.current_process.stdout.read(1024)
                    if not line_bytes:
                        break

                    raw_msg = line_bytes.decode('utf-8', errors='replace')

                    for part in raw_msg.splitlines(keepends=True):
                        msg = part.strip('\n\r ')
                        if not msg:
                            continue

                        if callback:
                            # --- Progress parsing ---
                            progress_match = re.search(r"(\d+)%", msg)
                            if progress_match:
                                await callback(f"[PROGRESS] {progress_match.group(1)}")

                            # --- Status recognition ---
                            if "Installing" in msg or "正在安装" in msg:
                                await callback("[INFO] Installing dependencies...")

                            # --- Raw log relay ---
                            await callback(f"[INFO] {msg}")

                        # Local console debug
                        print(f"\r[Process] {msg[:80]}...", end="", flush=True)
                        if '\n' in part:
                            print()

            return_code = await self.current_process.wait()

            if return_code == 0:
                res = "[INFO] Success"
            else:
                res = f"[ERROR] Failed with exit code: {return_code}"

            if callback:
                await callback(res)
            return return_code == 0

        except Exception as e:
            error_msg = f"[ERROR] Runtime Error during command execution: {str(e)}"
            if callback:
                await callback(error_msg)
            return False

        finally:
            self.current_process = None

    async def install(self, package_name: str, callback=None):
        """Install logic"""
        cmd = ["yay", "-S", "--noconfirm", "--needed", package_name]
        return await self._run_command(cmd, callback=callback)

    async def uninstall(self, package_name: str, callback=None):
        """Uninstall logic"""
        if callback:
            await callback(f"[INFO] Uninstalling {package_name}...")
        cmd = ["yay", "-Rs", "--noconfirm", package_name]
        return await self._run_command(cmd, callback=callback)

    def stop(self):
        """Safe stop"""
        if self.current_process:
            try:
                self.current_process.terminate()
                return "Process terminated."
            except Exception as e:
                return f"Stop failed: {e}"
        return "No process running."
