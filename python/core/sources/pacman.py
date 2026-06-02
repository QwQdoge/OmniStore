import subprocess
import re
import asyncio
import os
from typing import List, Dict, Any, Optional
from core.sources.base import UnifiedSource
from core.sources.utils import PrivilegeManager

_PKG_HEADER_RE = re.compile(r'^([^\s/]+)/([^\s]+)\s+([^\s]+)(.*)$')

class PacmanSource(UnifiedSource):
    def __init__(self, weight: float = 1.0):
        super().__init__(name="Pacman", weight=weight)
        self.enabled = os.path.exists("/usr/bin/pacman")
        self.privilege = PrivilegeManager()

    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        if not self.enabled:
            return []

        try:
            proc = await asyncio.create_subprocess_exec(
                'pacman', '-Ss', query,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            )
            stdout, _ = await proc.communicate()
            raw_output = stdout.decode().strip()
            if not raw_output:
                return []

            packages = []
            current_pkg = None

            for line in raw_output.splitlines():
                if not line.strip():
                    continue

                header_match = _PKG_HEADER_RE.match(line)
                if header_match:
                    if current_pkg:
                        packages.append(current_pkg)

                    repo, name, version, extra = header_match.groups()
                    current_pkg = {
                        "name": name,
                        "repo": repo,
                        "last_version": version,
                        "source": "Pacman",
                        "description": "",
                        "installed": "[installed]" in extra,
                        "variants": [{
                            "source": "Pacman",
                            "version": version,
                            "installed": "[installed]" in extra
                        }]
                    }
                elif current_pkg and line.startswith("    "):
                    current_pkg["description"] += line.strip() + " "

            if current_pkg:
                packages.append(current_pkg)

            return packages
        except Exception:
            return []

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        if not await self.privilege.ensure_privileged(callback):
            return False

        name = package.get("name")
        if callback:
            await callback(f"[INFO] Running: sudo pacman -S --noconfirm {name}")

        proc = await asyncio.create_subprocess_exec(
            "sudo", "pacman", "-S", "--noconfirm", name,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT
        )

        if proc.stdout:
            while True:
                line = await proc.stdout.readline()
                if not line:
                    break
                if callback:
                    await callback(line.decode().strip())

        await proc.wait()
        return proc.returncode == 0

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        if not await self.privilege.ensure_privileged(callback):
            return False

        name = package.get("name")
        if callback:
            await callback(f"[INFO] Running: sudo pacman -Rs --noconfirm {name}")

        proc = await asyncio.create_subprocess_exec(
            "sudo", "pacman", "-Rs", "--noconfirm", name,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT
        )

        if proc.stdout:
            while True:
                line = await proc.stdout.readline()
                if not line:
                    break
                if callback:
                    await callback(line.decode().strip())

        await proc.wait()
        return proc.returncode == 0

    async def launch(self, package: Dict[str, Any]) -> bool:
        name = package.get("name")
        try:
            subprocess.Popen([name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except Exception:
            return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        # For pacman, "locate" could mean listing files or finding the binary
        name = package.get("name")
        try:
            proc = await asyncio.create_subprocess_exec(
                "which", name,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            )
            stdout, _ = await proc.communicate()
            if proc.returncode == 0:
                # Open the directory containing the binary
                binary_path = stdout.decode().strip()
                binary_dir = os.path.dirname(binary_path)
                subprocess.Popen(["xdg-open", binary_dir], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return True
        except Exception:
            pass
        return False

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        try:
            proc = await asyncio.create_subprocess_exec(
                "pacman", "-Si", package_id,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            )
            stdout, _ = await proc.communicate()
            if stdout:
                info = stdout.decode()
                details = {"name": package_id, "source": "Pacman"}
                # Parse key info (dependencies, size, etc.)
                for line in info.splitlines():
                    if ":" in line:
                        key, val = line.split(":", 1)
                        key = key.strip()
                        val = val.strip()
                        if key == "Depends On": details["depends"] = val.split()
                        elif key == "Installed Size": details["installed_size"] = val
                        elif key == "Description": details["description"] = val
                return details
        except Exception:
            pass
        return {}

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        # This is complex for pacman without -Sy. Usually handled by UpdateManager.
        return None
