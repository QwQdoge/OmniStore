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
        return None

    async def list_installed(self) -> List[Dict[str, Any]]:
        res: List[Dict[str, Any]] = []
        if not self.enabled:
            return res
        try:
            async with safe_subprocess("pacman", "-Qqne", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                stdout, _ = await proc.communicate()
                for line in stdout.decode(errors="ignore").splitlines():
                    name = line.strip()
                    if name:
                        size = await self.get_size({"name": name, "id": name})
                        res.append({
                            "name": name,
                            "id": name,
                            "primary_source": "Pacman",
                            "source": "Pacman",
                            "managed": True,
                            "installed": True,
                            "description": "Native package",
                            "version": "Local",
                            **size,
                            "variants": [{"source": "Pacman", "id": name, "installed": True, "managed": True, **size}],
                        })
        except Exception:
            pass
        return res

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
