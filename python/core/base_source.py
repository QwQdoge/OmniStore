from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional

class BaseSource(ABC):
    """
    Strict abstract base class for all software sources in Omnistore.
    All plugins in python/source/ MUST inherit from this class and implement
    the required abstract methods.
    """

    def __init__(self, name: str, enabled: bool = True, weight: float = 1.0):
        self.name = name
        self.enabled = enabled
        self.weight = weight

    @property
    @abstractmethod
    def capabilities(self) -> Dict[str, bool]:
        """
        Capabilities Manifest.
        Defines what features this source supports. The frontend uses this to dynamically
        render or hide UI elements.

        Standard keys (should return boolean):
        - has_rating: Supports star ratings/reviews
        - has_screenshots: Can provide application screenshots
        - has_size: Can provide download/install size
        - has_versions: Supports selecting or viewing different versions
        - has_publisher: Provides publisher/author information
        - can_download: Can download/install the application
        - can_uninstall: Can uninstall the application
        - can_launch: Can launch the installed application
        - can_locate: Can locate the application directory
        """
        pass

    @abstractmethod
    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        """Search for packages in this source."""
        pass

    @abstractmethod
    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        """Install a package. Should handle progress callbacks if supported."""
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
        """Fetch detailed information about a package (e.g., screenshots, long description)."""
        pass

    @abstractmethod
    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        """Check for updates for a specific package."""
        pass

    async def get_recommendations(self) -> Dict[str, List[Dict[str, Any]]]:
        """Fetch recommendations (featured, trending, for_you). Default is empty."""
        return {"featured": [], "trending": [], "for_you": []}

    def to_dict(self) -> Dict[str, Any]:
        """Serialize source info and capabilities for the frontend."""
        return {
            "name": self.name,
            "enabled": self.enabled,
            "weight": self.weight,
            "capabilities": self.capabilities
        }
