import asyncio
import os
from typing import Any, Dict, List

from core.sources.external import AptSource, DnfSource, ZypperSource, ApkSource
from core.sources.utils import PrivilegeManager
from core.subprocess_utils import safe_subprocess


class _PrivilegedNativeMixin:
    """Run host package-manager mutations with explicit privilege handling.

    Search/list/details remain inherited from the existing source classes and do
    not require privilege. Only host mutations are elevated.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._privilege_manager = PrivilegeManager()

    def _install_command(self, package_id: str) -> List[str]:
        raise NotImplementedError

    def _uninstall_command(self, package_id: str) -> List[str]:
        raise NotImplementedError

    async def _run_mutation(self, command: List[str], callback=None, timeout: int = 3600) -> bool:
        callback = self._async_callback(callback)
        if not self.enabled:
            if callback:
                await callback(f"[ERROR] {self.name} is not available on this system.")
            return False

        if os.name != "nt" and os.geteuid() != 0:
            if not await self._privilege_manager.ensure_privileged(callback):
                return False
            command = ["sudo", "-n", *command]

        if callback:
            await callback(f"[INFO] Running {self.name} package operation...")
            await callback("[PROGRESS] 10")

        try:
            async with safe_subprocess(
                *command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            ) as proc:
                if proc.stdout:
                    while True:
                        raw = await proc.stdout.readline()
                        if not raw:
                            break
                        line = raw.decode("utf-8", errors="replace").strip()
                        if line and callback:
                            await callback(f"[INFO] {line}")
                await asyncio.wait_for(proc.wait(), timeout=timeout)
                success = proc.returncode == 0
        except asyncio.TimeoutError:
            if callback:
                await callback(f"[ERROR] {self.name} operation timed out.")
            return False
        except Exception as exc:
            if callback:
                await callback(f"[ERROR] {self.name} operation failed: {exc}")
            return False

        if callback:
            if success:
                await callback("[PROGRESS] 100")
            else:
                await callback(f"[ERROR] {self.name} exited with a non-zero status.")
        return success

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        package_id = self._package_id(package)
        if not package_id:
            if callback:
                await callback(f"[ERROR] {self.name} package id is missing.")
            return False
        return await self._run_mutation(self._install_command(package_id), callback=callback)

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        package_id = self._package_id(package)
        if not package_id:
            if callback:
                await callback(f"[ERROR] {self.name} package id is missing.")
            return False
        return await self._run_mutation(self._uninstall_command(package_id), callback=callback, timeout=1800)


class PrivilegedAptSource(_PrivilegedNativeMixin, AptSource):
    def _install_command(self, package_id: str) -> List[str]:
        return ["apt-get", "install", "-y", package_id]

    def _uninstall_command(self, package_id: str) -> List[str]:
        return ["apt-get", "remove", "-y", package_id]


class PrivilegedDnfSource(_PrivilegedNativeMixin, DnfSource):
    def _install_command(self, package_id: str) -> List[str]:
        return ["dnf", "install", "-y", package_id]

    def _uninstall_command(self, package_id: str) -> List[str]:
        return ["dnf", "remove", "-y", package_id]


class PrivilegedZypperSource(_PrivilegedNativeMixin, ZypperSource):
    def _install_command(self, package_id: str) -> List[str]:
        return ["zypper", "--non-interactive", "install", package_id]

    def _uninstall_command(self, package_id: str) -> List[str]:
        return ["zypper", "--non-interactive", "remove", package_id]


class PrivilegedApkSource(_PrivilegedNativeMixin, ApkSource):
    def _install_command(self, package_id: str) -> List[str]:
        return ["apk", "add", package_id]

    def _uninstall_command(self, package_id: str) -> List[str]:
        return ["apk", "del", package_id]
