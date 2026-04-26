import asyncio
import os
import re
from typing import List


class FlatpakDownloader:
    def __init__(self, executor):
        self.executor = executor
        self.flathub_url = "https://dl.flathub.org/repo/flathub.flatpakrepo"

    async def install(self, app_id: str, callback=None):
        # 1. Ensure Flathub repository is added
        if callback:
            await callback("[INFO] Ensuring Flathub repository is configured...")
        add_repo_cmd = [
            "flatpak", "remote-add", "--if-not-exists", "--user", 
            "flathub", "https://dl.flathub.org/repo/flathub.flatpakrepo"
        ]
        await self._run_flatpak_command(add_repo_cmd, callback=callback, is_install=False)

        # 2. Execute installation
        if callback:
            await callback(f"[INFO] Installing {app_id} from Flathub...")
        install_cmd = [
            "flatpak", "install", "--user", "-y", 
            "--noninteractive", "flathub", app_id
        ]
        await self._run_flatpak_command(install_cmd, callback=callback, is_install=True)

    async def _run_flatpak_command(self, cmd: List[str], callback=None, is_install=False):
        try:
            # Mask environment to make Flatpak think it's in a terminal
            env = {
                **os.environ,
                "LC_ALL": "C",
                "TERM": "xterm-256color",
                "COLUMNS": "100",
                "PYTHONUNBUFFERED": "1"
            }

            self.current_process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                env=env
            )
            process = self.current_process

            last_sent_progress = -1

            if process.stdout:
                while True:
                    chunk = await process.stdout.read(1024)
                    if not chunk:
                        break
                    raw_data = chunk.decode('utf-8', errors='ignore')

                    if not is_install:
                        if callback:
                            for line in raw_data.splitlines():
                                line = line.strip()
                                if line:
                                    await callback(f"[INFO] {line}")
                        continue

                    # 1. Match summary: Installing 3/8... 19%
                    summary_match = re.search(
                        r"(\d+)/(\d+).*?(\d+)\s*%", raw_data)

                    # 2. Match progress in list: [  19%]
                    list_progress_match = re.search(
                        r"\[\s*(\d+)%\s*\]", raw_data)

                    total_prog = None

                    if summary_match:
                        cur, total, sub = map(int, summary_match.groups())
                        total_prog = int(((cur - 1) / total)
                                         * 100 + (sub / total))
                    elif list_progress_match:
                        total_prog = int(list_progress_match.group(1))

                    if total_prog is not None and total_prog > last_sent_progress:
                        if callback:
                            await callback(f"[PROGRESS] {total_prog}")
                        last_sent_progress = total_prog

            await process.wait()
            self.current_process = None
            if is_install and process.returncode == 0:
                if callback:
                    await callback("[PROGRESS] 100")

        except Exception as e:
            if callback:
                await callback(f"[ERROR] Flatpak command failed: {e}")
            self.current_process = None

    async def uninstall(self, app_id: str, callback=None):
        """Uninstall and clean residue"""
        if callback:
            await callback(f"[INFO] Uninstalling {app_id}...")

        cmd = ["flatpak", "uninstall", "--user", "-y", "--noninteractive", app_id]
        await self._run_flatpak_command(cmd, callback=callback)

        # Cleanup unused runtimes
        if callback:
            await callback("[INFO] Cleaning unused runtimes...")
        unused_cmd = ["flatpak", "uninstall", "--user", "--unused", "-y", "--noninteractive"]
        await self._run_flatpak_command(unused_cmd, callback=callback)

    def stop(self):
        """Flatpak stop logic"""
        if hasattr(self, 'current_process') and self.current_process:
            try:
                self.current_process.terminate()
            except Exception:
                pass
