from core.sources.base import UnifiedSource
from typing import List, Dict, Any, Optional

class DemoPlugin(UnifiedSource):
    def __init__(self):
        super().__init__(name="DemoPlugin", weight=1.0)
        self.enabled = True

    async def search(self, query: str) -> List[Dict[str, Any]]:
        if query == "test":
            return [{
                "name": "Demo Package",
                "source": "DemoPlugin",
                "description": "This is a package from a dynamic plugin!",
                "installed": False,
                "variants": [{"source": "DemoPlugin", "version": "1.0.0", "installed": False}]
            }]
        return []

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        if callback: await callback("[INFO] Demo installation...")
        return True

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        return True

    async def launch(self, package: Dict[str, Any]) -> bool:
        return True

    async def locate(self, package: Dict[str, Any]) -> bool:
        return True

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        return {}

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        return None
