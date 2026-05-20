import asyncio
import aiohttp
from aiohttp import ClientTimeout
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from .base import SearchSource
from typing import List, Dict, Any


class AppImageSearch(SearchSource):
    FEED_URL = "https://appimage.github.io/feed.json"
    headers = {
        "User-Agent": "Omnistore/0.1 (https://github.com/omnistore/omnistore)"
    }

    def __init__(self, session: aiohttp.ClientSession, config_manager: Any):
        super().__init__(name="AppImage")
        self.session = session
        self.cm = config_manager
        self.cache: List[Dict] = []  # Cache for AppImage data
        self.cache_timestamp = 0  # Timestamp in seconds
        self.cache_duration = 3600  # 1 hour validity
        self.lock = asyncio.Lock()
        self.executor = ThreadPoolExecutor(max_workers=2)

    async def _fetch_single_feed(self, url: str) -> List[Dict]:
        try:
            async with self.session.get(url, headers=self.headers, timeout=ClientTimeout(total=8)) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    return data.get("items", [])
                else:
                    print(f"Failed to fetch AppImage feed {url}: HTTP {resp.status}")
                    return []
        except Exception as e:
            print(f"Exception while fetching AppImage feed {url}: {e}")
            return []

    async def _fetch_feed(self) -> List[Dict]:
        async with self.lock:
            current_time = asyncio.get_event_loop().time()
            if self.cache and (current_time - self.cache_timestamp < self.cache_duration):
                return self.cache

            # Gather from standard feed & custom feeds from config
            feeds = [self.FEED_URL]
            custom_feeds = self.cm.get("custom_repos.appimage", [])
            if isinstance(custom_feeds, list):
                feeds.extend(custom_feeds)

            tasks = [self._fetch_single_feed(url) for url in feeds]
            results = await asyncio.gather(*tasks)

            merged_items = []
            seen_names = set()
            for items in results:
                for item in items:
                    name = item.get("name")
                    if name and name not in seen_names:
                        seen_names.add(name)
                        merged_items.append(item)

            self.cache = merged_items
            self.cache_timestamp = current_time
            return merged_items

    def _extract_download_url(self, links):
        if not links:
            return ""
        for link in links:
            if link.get("type") == "Download":
                return link.get("url", "")
        return ""

    def is_installed(self, app_name: str) -> bool:
        apps_dir = Path.home() / "Applications"
        if not apps_dir.exists():
            return False
        return any(app_name.lower() in f.name.lower() for f in apps_dir.glob("*.AppImage"))

    async def search(self, query: str) -> List[Dict]:
        if not query or len(query) < 2:
            return []

        feed_items = await self._fetch_feed()
        query_lower = query.lower()

        matched_items = [
            item for item in feed_items
            if query_lower in item.get("name", "").lower()
            or query_lower in item.get("description", "").lower()
        ]

        if not matched_items:
            return []

        loop = asyncio.get_event_loop()
        tasks = [
            loop.run_in_executor(
                self.executor, self.is_installed, item.get("name", ""))
            for item in matched_items
        ]

        installed_statuses = await asyncio.gather(*tasks)

        results = []
        for item, is_inst in zip(matched_items, installed_statuses):
            results.append({
                "name": item.get("name", ""),
                "last_version": item.get("version", ""),
                "description": item.get("description", ""),
                "source": self.name,
                "votes": 0,
                "installed": is_inst,
                "url": self._extract_download_url(item.get("links", []))
            })

        return results
