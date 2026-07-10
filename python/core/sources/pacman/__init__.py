import asyncio
from core.subprocess_utils import safe_subprocess
from typing import Dict, Any, List, Optional, Callable
from core.sources.pacman.search import search_pacman, get_pacman_details
from core.sources.pacman.download import install_pacman, uninstall_pacman
from core.sources.base import UnifiedSource
import subprocess
import os

class PacmanSource(UnifiedSource):
    def __init__(self, weight: float = 1.0):
        super().__init__(name="Pacman", weight=weight)
        self.enabled = os.path.exists("/usr/bin/pacman")

    def config_schema(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "mirrorlist_path": {
                    "type": "string",
                    "default": "/etc/pacman.d/mirrorlist",
                    "description": "Pacman mirrorlist path for preview and privileged edits.",
                },
                "repositories": {
                    "type": "array",
                    "description": "Additional pacman repositories.",
                    "items": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string"},
                            "server": {"type": "string"},
                            "enabled": {"type": "boolean", "default": True},
                        },
                        "required": ["name", "server"],
                    },
                },
            },
        }

    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:
        return await search_pacman(query, page)

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        return await install_pacman(package, callback)

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        return await uninstall_pacman(package, callback)

    async def launch(self, package: Dict[str, Any]) -> bool:
        name = package.get("name")
        try:
            async with safe_subprocess(name, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL):
                return True
        except Exception:
            return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        name = package.get("name")
        try:
            async with safe_subprocess(
                "which", name,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            ) as proc:
                stdout, _ = await proc.communicate()
                if proc.returncode == 0:
                    binary_path = stdout.decode().strip()
                    binary_dir = os.path.dirname(binary_path)
                    async with safe_subprocess("xdg-open", binary_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL):
                        return True
        except Exception:
            pass
        return False

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        return await get_pacman_details(package_id)

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        if not self.enabled or not package_id:
            return None
        try:
            async with safe_subprocess("pacman", "-Qu", package_id, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL, env={**os.environ, "LC_ALL": "C"}) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
                for line in stdout.decode(errors="ignore").splitlines():
                    parts = line.split()
                    if len(parts) >= 4 and parts[0] == package_id:
                        return {
                            "name": parts[0],
                            "id": parts[0],
                            "source": "Pacman",
                            "current_version": parts[1],
                            "new_version": parts[3],
                        }
        except Exception:
            return None
        return None

    async def list_installed(self) -> List[Dict[str, Any]]:
        res: List[Dict[str, Any]] = []
        if not self.enabled:
            return res
        try:
            # ⚡ Bolt: Consolidated metadata and size retrieval into a single O(1) subprocess call
            # 1. Get explicitly installed foreign packages to filter them out (matching -n behavior)
            async with safe_subprocess("pacman", "-Qqme", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                stdout_f, _ = await proc.communicate()
                foreign_explicit = {line.strip() for line in stdout_f.decode(errors="ignore").splitlines() if line.strip()}

            # 2. Use a single 'pacman -Qie' call to get details for all explicitly installed packages
            async with safe_subprocess("pacman", "-Qie", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL, env={**os.environ, "LC_ALL": "C"}) as proc:
                stdout, _ = await proc.communicate()
                raw_info = stdout.decode(errors="ignore")

                current_pkg = {}
                for line in raw_info.splitlines():
                    if not line.strip():
                        if current_pkg and current_pkg.get("name") not in foreign_explicit:
                            res.append(self._format_installed_pkg(current_pkg))
                        current_pkg = {}
                        continue

                    if " : " in line:
                        key, val = line.split(" : ", 1)
                        key = key.strip()
                        val = val.strip()
                        if key == "Name": current_pkg["name"] = val
                        elif key == "Version": current_pkg["version"] = val
                        elif key == "Description": current_pkg["description"] = val
                        elif key == "Installed Size": current_pkg["installed_size"] = val

                if current_pkg and current_pkg.get("name") not in foreign_explicit:
                    res.append(self._format_installed_pkg(current_pkg))
        except Exception:
            pass
        return res

    def _format_installed_pkg(self, pkg: Dict[str, str]) -> Dict[str, Any]:
        name = pkg.get("name", "unknown")
        size_info = {
            "download_size": None,
            "installed_size": pkg.get("installed_size"),
            "disk_size": None,
            "size_confidence": "reported" if pkg.get("installed_size") else "unknown",
            "size_source": "pacman -Qi",
        }
        return {
            "name": name,
            "id": name,
            "primary_source": "Pacman",
            "source": "Pacman",
            "managed": True,
            "installed": True,
            "description": pkg.get("description", "Native package"),
            "version": pkg.get("version", "Local"),
            **size_info,
            "variants": [{"source": "Pacman", "id": name, "installed": True, "managed": True, **size_info}],
        }

    async def get_size(self, package: Dict[str, Any]) -> Dict[str, Any]:
        name = package.get("id") or package.get("name")
        if not name or not self.enabled:
            return await super().get_size(package)
        try:
            async with safe_subprocess("pacman", "-Qi", str(name), stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL, env={**os.environ, "LC_ALL": "C"}) as proc:
                stdout, _ = await proc.communicate()
                info = stdout.decode(errors="ignore")
                installed_size = None
                for line in info.splitlines():
                    if line.startswith("Installed Size"):
                        installed_size = line.split(":", 1)[1].strip()
                        break
                return {
                    "download_size": None,
                    "installed_size": installed_size,
                    "disk_size": None,
                    "size_confidence": "reported" if installed_size else "unknown",
                    "size_source": "pacman -Qi",
                }
        except Exception:
            return await super().get_size(package)
