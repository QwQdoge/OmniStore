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
