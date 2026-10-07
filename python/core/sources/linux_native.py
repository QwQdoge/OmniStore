import asyncio
import os
import re
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

        environment = None
        if os.name != "nt" and os.geteuid() != 0:
            try:
                environment = await self._privilege_manager.subprocess_environment()
            except RuntimeError:
                if callback:
                    await callback(f"[ERROR] Graphical authorization is unavailable for {self.name}.")
                return False
            command = ["sudo", "-A", *command]

        if callback:
            await callback(f"[INFO] Running {self.name} package operation...")
            await callback("[PROGRESS] 10")

        try:
            async with safe_subprocess(
                *command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                stdin=asyncio.subprocess.DEVNULL,
                env=environment,
            ) as proc:
                async with asyncio.timeout(timeout):
                    if proc.stdout:
                        async for raw in proc.stdout:
                            line = raw.decode("utf-8", errors="replace").strip()
                            if line and callback:
                                await callback(f"[INFO] {line}")
                    await proc.wait()
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
        callback = self._async_callback(callback)
        package_id = self._package_id(package)
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9+._:-]{0,199}", package_id):
            if callback:
                await callback(f"[ERROR] {self.name} package id is invalid.")
            return False
        return await self._run_mutation(self._install_command(package_id), callback=callback)

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        callback = self._async_callback(callback)
        package_id = self._package_id(package)
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9+._:-]{0,199}", package_id):
            if callback:
                await callback(f"[ERROR] {self.name} package id is invalid.")
            return False
        return await self._run_mutation(self._uninstall_command(package_id), callback=callback, timeout=1800)

    async def list_installed(self):
        if not self.enabled:
            return []
        command = {
            "apt": ["dpkg-query", "-W", "-f=${binary:Package}\t${Version}\t${db:Status-Abbrev}\n"],
            "dnf": ["rpm", "-qa", "--qf", "%{NAME}.%{ARCH}\t%{VERSION}-%{RELEASE}\n"],
            "zypper": ["rpm", "-qa", "--qf", "%{NAME}\t%{VERSION}-%{RELEASE}\n"],
            "apk": ["apk", "info"],
        }[self.manager_id]
        try:
            async with safe_subprocess(
                *command, stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
                env={**os.environ, "LC_ALL": "C"},
            ) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=30)
                if proc.returncode != 0:
                    return []
            installed = []
            for line in stdout.decode("utf-8", errors="replace").splitlines():
                fields = line.split("\t")
                package_id = fields[0].strip()
                if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9+._:-]{0,199}", package_id):
                    continue
                if self.manager_id == "apt" and (len(fields) < 3 or not fields[2].startswith("ii")):
                    continue
                version = fields[1] if len(fields) > 1 else "Unknown"
                installed.append({"id": package_id, "name": package_id,
                                  "source": self.name, "primary_source": self.manager_id,
                                  "installed": True, "last_version": version,
                                  "installed_version": version})
            return installed
        except Exception:
            return []


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
    def _parse_search_output(self, output, query):
        results = []
        seen = set()
        for line in output.splitlines():
            fields = [part.strip() for part in line.split("|")]
            if len(fields) != 4 or fields[3] != "package":
                continue
            status, package_id, summary, _ = fields
            if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9+._:-]{0,199}", package_id) or package_id in seen:
                continue
            seen.add(package_id)
            installed = status.startswith("i")
            results.append({"id": package_id, "name": package_id, "source": self.name,
                            "primary_source": self.manager_id, "description": summary,
                            "installed": installed, "last_version": "Unknown",
                            "variants": [{"id": package_id, "source": self.name,
                                          "installed": installed, "version": "Unknown"}]})
            if len(results) >= 50:
                break
        return results

    def _install_command(self, package_id: str) -> List[str]:
        return ["zypper", "--non-interactive", "install", package_id]

    def _uninstall_command(self, package_id: str) -> List[str]:
        return ["zypper", "--non-interactive", "remove", package_id]


class PrivilegedApkSource(_PrivilegedNativeMixin, ApkSource):
    def _install_command(self, package_id: str) -> List[str]:
        return ["apk", "add", package_id]

    def _uninstall_command(self, package_id: str) -> List[str]:
        return ["apk", "del", package_id]
