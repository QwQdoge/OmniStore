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

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "enabled": self.enabled,
            "weight": self.weight
        }
