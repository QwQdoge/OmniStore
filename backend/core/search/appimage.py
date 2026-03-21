import asyncio
import aiohttp
from aiohttp import ClientTimeout
from typing import List, Dict
from .base import SearchSource

class AppImageSource(SearchSource):
    FEED_URL = "https://appimage.github.io/feed.json"
    HEADERS = {"User-Agent": "OmniArch/1.0 (Arch Linux)"}

    def __init__(self, name: str):
        super().__init__(name)
        self._cache: List[Dict] = []
        self._lock = asyncio.Lock()
        self._download_task = None  # 追踪正在进行的下载任务

    async def _ensure_cache(self):
        """内部方法：确保缓存存在，支持并发调用"""
        async with self._lock:
            if self._cache:
                return
            
            # 如果已经有一个下载任务在跑了，就直接 await 它，而不是开启新任务
            if self._download_task is None:
                self._download_task = asyncio.create_task(self._do_download())
            
        await self._download_task

    async def _do_download(self):
        """实际执行下载的私有方法"""
        timeout = ClientTimeout(total=30) # 进一步放宽到 30 秒
        async with aiohttp.ClientSession(headers=self.HEADERS) as session:
            try:
                print(f"[AppImage] Starting single-shot download...")
                async with session.get(self.FEED_URL, timeout=timeout) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        self._cache = data.get("items", [])
                        print(f"[AppImage] Successfully cached {len(self._cache)} items.")
                    else:
                        print(f"[AppImage] HTTP {resp.status} Error")
            except Exception as e:
                print(f"[AppImage] Download error: {e}")
            finally:
                # 无论成功失败，下载任务标记为结束
                self._download_task = None

    async def search(self, query: str) -> List[Dict]:
        if not self.enabled: return []

        # 1. 确保缓存。不管多少个并发搜素，最终只会进一次 _do_download
        await self._ensure_cache()

        # 2. 搜索逻辑
        query_lower = query.lower().strip()
        if not query_lower: return []

        results = []
        for item in self._cache:
            name = str(item.get("name") or item.get("title") or "")
            desc = str(item.get("description") or item.get("summary") or "")
            if query_lower in name.lower() or query_lower in desc.lower():
                links = item.get("links", [])
                results.append({
                    "name": name,
                    "desc": desc,
                    "version": "Latest",
                    "source": "AppImage",
                    "url": links[0].get("url", "") if links else "",
                    "is_installed": False,
                    "votes": 0
                })
        return results[:30]