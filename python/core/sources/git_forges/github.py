import aiohttp
from typing import List, Dict, Any, Optional
from .base import GitForge

class GitHubForge(GitForge):
    def __init__(self, session: aiohttp.ClientSession):
        super().__init__(name="GitHub", host="github.com")
        self.session = session
        self.api_base = "https://api.github.com"
        self.headers = {"Accept": "application/vnd.github.v3+json", "User-Agent": "Omnistore/0.1"}

    async def search_repositories(self, query: str, sort: str = "stars", order: str = "desc") -> List[Dict[str, Any]]:
        url = f"{self.api_base}/search/repositories"
        params = {"q": query, "sort": sort, "order": order}
        async with self.session.get(url, headers=self.headers, params=params) as resp:
            if resp.status == 200:
                data = await resp.json()
                return data.get("items", [])
        return []

    async def get_latest_release(self, owner: str, repo: str) -> Optional[Dict[str, Any]]:
        url = f"{self.api_base}/repos/{owner}/{repo}/releases/latest"
        async with self.session.get(url, headers=self.headers) as resp:
            if resp.status == 200:
                return await resp.json()
        return None

    async def get_repository_info(self, owner: str, repo: str) -> Optional[Dict[str, Any]]:
        url = f"{self.api_base}/repos/{owner}/{repo}"
        async with self.session.get(url, headers=self.headers) as resp:
            if resp.status == 200:
                return await resp.json()
        return None

    async def get_trending(self) -> List[Dict[str, Any]]:
        # Simplified trending using star count filter
        return await self.search_repositories("stars:>10000")
