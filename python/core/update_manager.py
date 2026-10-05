import asyncio
import fcntl
from core.subprocess_utils import safe_subprocess
import shutil
import re
import inspect
import os
import platform
from pathlib import Path
from typing import Awaitable, Callable, List, Dict, Optional

from core.sources.utils import PrivilegeManager
from core.update_state import build_state, normalize_candidate, write_state

class UpdateManager:
    def __init__(self, config=None):
        self.config = config
        self.privilege = PrivilegeManager()

    async def apply_all_updates(
        self,
        callback: Optional[Callable[[str], Awaitable[None]]] = None,
    ) -> bool:
        """Apply updates through each supported system manager.

        This is intentionally an explicit orchestration path. Passing a fake
        package named ``all`` to an individual source can install the wrong
        package or report a false success.
        """
        lock_file = self._acquire_update_lock()
        if lock_file is None:
            await self._emit(
                callback,
                "[ERROR] Another system update is already running for this user.",
            )
            return False
        try:
            return await self._apply_all_updates_locked(callback)
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
            lock_file.close()

    async def _apply_all_updates_locked(
        self,
        callback: Optional[Callable[[str], Awaitable[None]]] = None,
    ) -> bool:
        commands = []
        privilege_env = None
        if shutil.which("pacman"):
            try:
                # Do not run a separate sudo -v probe here. The real Pacman
                # command is the authorization boundary, so GUI users see one
                # prompt instead of a validation prompt followed by execution.
                privilege_env = await self.privilege.subprocess_environment()
            except RuntimeError as exc:
                await self._emit(callback, f"[ERROR] {exc}")
                return False
            commands.append(("Pacman", ["sudo", "-A", "pacman", "-Syu", "--noconfirm"], privilege_env))
        if shutil.which("flatpak"):
            commands.append(("Flatpak", ["flatpak", "update", "--user", "-y"], None))
        include_aur = bool(
            self.config
            and self.config.get("updates.include_aur_in_update_all", False)
        )
        if include_aur and shutil.which("yay"):
            if privilege_env is None:
                try:
                    privilege_env = await self.privilege.subprocess_environment()
                except RuntimeError as exc:
                    await self._emit(callback, f"[ERROR] {exc}")
                    return False
            # Pacman already handled repository packages above. -Sua limits
            # this phase to AUR packages and avoids a duplicate system upgrade
            # plus its extra authorization requests.
            commands.append(("AUR", ["yay", "--sudoflags", "-A", "-Sua", "--noconfirm"], privilege_env))

        if not commands:
            await self._emit(callback, "[ERROR] No supported update manager is available.")
            return False

        succeeded = True
        for index, (name, command, command_env) in enumerate(commands):
            await self._emit(callback, f"[INFO] Updating {name} packages...")
            if not await self._run_update_command(command, callback, env=command_env):
                succeeded = False
                await self._emit(callback, f"[ERROR] {name} update failed.")
            await self._emit(
                callback,
                f"[PROGRESS] {round(((index + 1) / len(commands)) * 100)}",
            )
        if succeeded:
            await self._emit(callback, "[INFO] All enabled package sources are up to date.")
            postflight = await self.postflight_report()
            try:
                write_state(build_state([], postflight=postflight))
            except (OSError, ValueError) as exc:
                await self._emit(callback, f"[WARNING] Could not persist update status: {exc}")
            await self._emit_postflight(callback, postflight)
        return succeeded

    @staticmethod
    def _acquire_update_lock():
        """Take a per-user, non-blocking lock for the mutating update path."""
        runtime_dir = os.environ.get("XDG_RUNTIME_DIR")
        if runtime_dir:
            lock_root = Path(runtime_dir)
        else:
            preferred = Path("/run/user") / str(os.getuid())
            lock_root = preferred if preferred.is_dir() else Path.home() / ".cache" / "omnistore"
        try:
            lock_root.mkdir(mode=0o700, parents=True, exist_ok=True)
            lock_file = (lock_root / "meo-update.lock").open("a+", encoding="utf-8")
            os.chmod(lock_file.name, 0o600)
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            lock_file.seek(0)
            lock_file.truncate()
            lock_file.write(f"{os.getpid()}\n")
            lock_file.flush()
            return lock_file
        except (OSError, BlockingIOError):
            try:
                lock_file.close()
            except (NameError, OSError):
                pass
            return None

    async def _run_update_command(self, command, callback, env=None) -> bool:
        try:
            async with safe_subprocess(
                *command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                env=env,
            ) as proc:
                if proc.stdout:
                    async for raw_line in proc.stdout:
                        line = raw_line.decode("utf-8", errors="replace").strip()
                        if line:
                            await self._emit(callback, f"[INFO] {line}")
                await proc.wait()
                return proc.returncode == 0
        except Exception as exc:
            await self._emit(callback, f"[ERROR] Update command failed: {exc}")
            return False

    @staticmethod
    async def _emit(callback, message: str) -> None:
        if callback is None:
            return
        result = callback(message)
        if inspect.isawaitable(result):
            await result

    async def check_all_updates(self) -> List[Dict]:
        tasks = []
        include_aur = True
        if self.config:
            include_aur = self.config.get("updates.include_aur_in_update_all", False)

        if shutil.which("pacman"):
            tasks.append(self.check_pacman_updates())
        if shutil.which("yay") and include_aur:
            tasks.append(self.check_aur_updates())
        if shutil.which("flatpak"):
            tasks.append(self.check_flatpak_updates())

        results = await asyncio.gather(*tasks, return_exceptions=True)

        combined = []
        for res in results:
            if isinstance(res, list):
                combined.extend(normalize_candidate(item) for item in res)
            elif isinstance(res, Exception):
                print(f"[UpdateManager] Error checking updates: {res}")

        try:
            write_state(build_state(combined))
        except (OSError, ValueError) as exc:
            print(f"[UpdateManager] Could not write shared update state: {exc}")
        return combined

    async def check_pacman_updates(self) -> List[Dict]:
        """Check for native package updates using checkupdates (pacman-contrib)"""
        if not shutil.which("checkupdates"):
            # Fallback to pacman -Qu if checkupdates is not installed
            # Note: pacman -Qu only works if the DB is already synced (pacman -Sy)
            return await self._run_qu_command(["pacman", "-Qu"], "Pacman")

        return await self._run_qu_command(["checkupdates"], "Pacman")

    async def check_aur_updates(self) -> List[Dict]:
        """Check for AUR updates using yay -Qua"""
        if not shutil.which("yay"):
            return []
        return await self._run_qu_command(["yay", "-Qua"], "AUR")

    async def _run_qu_command(self, cmd: List[str], source: str) -> List[Dict]:
        try:
            async with safe_subprocess(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            ) as proc:
                stdout, _ = await proc.communicate()
                if not stdout:
                    return []

                updates = []
                for line in stdout.decode().strip().splitlines():
                    # Format: pkgname old_version -> new_version
                    match = re.match(r"^([^\s]+)\s+([^\s]+)\s+->\s+([^\s]+)", line)
                    if match:
                        name, old_ver, new_ver = match.groups()
                        updates.append({
                            "id": name,
                            "resource_id": f"{source.casefold()}:{name}",
                            "source_id": source.casefold(),
                            "name": name,
                            "source": source,
                            "current_version": old_ver,
                            "new_version": new_ver,
                            "description": f"Update available from {source}"
                        })
                return updates
        except Exception:
            return []

    async def check_flatpak_updates(self) -> List[Dict]:
        """Check for Flatpak updates"""
        if not shutil.which("flatpak"):
            return []

        try:
            # columns: name, application, version, new-version
            async with safe_subprocess(
                "flatpak", "list", "--updates", "--columns=name,application,version,new-version",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            ) as proc:
                stdout, _ = await proc.communicate()
                if not stdout:
                    return []

                updates = []
                for line in stdout.decode().strip().splitlines():
                    parts = [p.strip() for p in line.split('\t')]
                    if len(parts) >= 4:
                        updates.append({
                            "resource_id": f"flatpak:{parts[1]}",
                            "source_id": "flatpak",
                            "name": parts[0],
                            "id": parts[1],
                            "source": "Flatpak",
                            "current_version": parts[2],
                            "new_version": parts[3],
                            "description": f"Flatpak update: {parts[1]}"
                        })
                return updates
        except Exception:
            return []

    async def postflight_report(self) -> Dict:
        """Report maintenance follow-ups without mutating or restarting anything."""
        report = {
            "reboot_required": False,
            "pacnew_files": [],
            "failed_units": [],
        }
        if platform.system() == "Linux":
            report["reboot_required"] = not os.path.exists(
                f"/usr/lib/modules/{platform.release()}/vmlinuz"
            )
        if shutil.which("pacdiff"):
            report["pacnew_files"] = await self._capture_lines(["pacdiff", "-o"], limit=128)
        if shutil.which("systemctl"):
            report["failed_units"] = await self._capture_lines(
                ["systemctl", "--failed", "--no-legend", "--plain"], limit=128
            )
        return report

    async def _capture_lines(self, command: List[str], *, limit: int) -> List[str]:
        try:
            async with safe_subprocess(
                *command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
            ) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=15)
                if proc.returncode not in (0, 1):
                    return []
                return [
                    line.strip()[:512]
                    for line in stdout.decode("utf-8", errors="replace").splitlines()
                    if line.strip()
                ][:limit]
        except Exception:
            return []

    async def _emit_postflight(self, callback, report: Dict) -> None:
        if report.get("reboot_required"):
            await self._emit(callback, "[WARNING] A reboot is required to load the installed kernel.")
        if report.get("pacnew_files"):
            await self._emit(callback, f"[WARNING] {len(report['pacnew_files'])} pacnew file(s) need review.")
        if report.get("failed_units"):
            await self._emit(callback, f"[WARNING] {len(report['failed_units'])} systemd unit(s) are failed.")
