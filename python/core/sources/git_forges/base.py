from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional

class GitForge(ABC):
    """Base class for all Git forges (GitHub, Codeberg, Forgejo)."""

    def __init__(self, name: str, host: str):
        self.name = name
        self.host = host

    @abstractmethod
    async def search_repositories(self, query: str, sort: str = "stars", order: str = "desc") -> List[Dict[str, Any]]:
        pass

    @abstractmethod
    async def get_latest_release(self, owner: str, repo: str) -> Optional[Dict[str, Any]]:
        pass

    @abstractmethod
    async def get_repository_info(self, owner: str, repo: str) -> Optional[Dict[str, Any]]:
        pass

    @abstractmethod
    async def get_trending(self) -> List[Dict[str, Any]]:
        pass
