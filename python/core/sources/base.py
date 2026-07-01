from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional

class UnifiedSource(ABC):
    """
    Unified interface for all software sources (Pacman, Flatpak, GitHub, Plugins, etc.)
    """
    def __init__(self, name: str, enabled: bool = True, weight: float = 1.0):
        self.name = name
        self.enabled = enabled
        self.weight = weight
        self.source_id = name.lower()
        self.display_name = name
        self.capabilities = {
            "search": True,
            "install": True,
            "uninstall": True,
            "update": True,
            "details": True,
            "list_installed": False,
            "size": False,
            "mirrors": False,
            "repositories": False,
            "launch": True,
            "locate": True,
        }

    @abstractmethod
    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:
        """Search for packages in this source with pagination and filters."""
        pass

    @abstractmethod
    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        """Install a package."""
        pass

    @abstractmethod
    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        """Uninstall a package."""
        pass

    @abstractmethod
    async def launch(self, package: Dict[str, Any]) -> bool:
        """Launch the application."""
        pass

    @abstractmethod
    async def locate(self, package: Dict[str, Any]) -> bool:
        """Locate the installation directory or app info."""
        pass

    @abstractmethod
    async def get_details(self, package_id: str) -> Dict[str, Any]:
        """Fetch detailed information about a package."""
        pass

    @abstractmethod
    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        """Check for updates for a specific package."""
        pass

    async def get_recommendations(self) -> Dict[str, List[Dict[str, Any]]]:
        """Fetch recommendations from this source."""
        return {"featured": [], "trending": [], "for_you": []}

    def config_schema(self) -> Dict[str, Any]:
        """Return optional JSON-schema style configuration for this plugin."""
        return {}

    def validate_config(self, config: Dict[str, Any]) -> bool:
        """Validate plugin-specific config. Sources can override for stricter checks."""
        return True

    async def health_check(self) -> Dict[str, Any]:
        """Return source availability metadata without throwing."""
        return {
            "source_id": self.source_id,
            "name": self.name,
            "enabled": self.enabled,
            "ok": bool(self.enabled),
        }

    async def list_installed(self) -> List[Dict[str, Any]]:
        """List apps installed by or visible to this source."""
        return []

    async def get_size(self, package: Dict[str, Any]) -> Dict[str, Any]:
        """Return normalized size metadata for a package."""
        return {
            "download_size": package.get("download_size"),
            "installed_size": package.get("installed_size"),
            "disk_size": package.get("disk_size"),
            "size_confidence": package.get("size_confidence", "unknown"),
            "size_source": package.get("size_source", self.name),
        }

    def to_dict(self) -> Dict[str, Any]:
        return {
            "source_id": self.source_id,
            "name": self.name,
            "display_name": self.display_name,
            "enabled": self.enabled,
            "weight": self.weight,
            "capabilities": self.capabilities,
        }
