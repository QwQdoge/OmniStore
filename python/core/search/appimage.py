import asyncio
import aiohttp
from aiohttp import ClientTimeout
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from .base import SearchSource
from typing import List, Dict

class AppImageSearch(SearchSource):
    FEED_URL = "https://appimage.github.io/feed.json"
    headers = {"User-Agent": "Omnistore/1.0 (https://github.com/omnistore/omnistore)"}

    def __init__(self, session: aiohttp.ClientSession):
        super().__init__(name="AppImage")
        self.session = session
        self.cache: List[Dict] = []  # 用于缓存 AppImage 数据，避免重复请求
        self.cache_timestamp = 0  # 记录缓存的时间戳，单位为秒
        self.cache_duration = 3600  # 缓存有效期，单位为秒
        self.lock = asyncio.Lock()  # 锁对象，确保缓存更新时的线程安全
        self._download_lock = asyncio.Lock()  # 锁对象，确保下载操作的线程安全
        self.executor = ThreadPoolExecutor(max_workers=2)  # 用于执行阻塞的文件系统操作，如检查安装状态

    async def _fetch_feed(self) -> List[Dict]:
        # 先检查缓存是否有效
        async with self.lock:
            current_time = asyncio.get_event_loop().time()
            if self.cache and (current_time - self.cache_timestamp < self.cache_duration):
                return self.cache  # 返回缓存数据
            
            # 缓存无效，重新请求数据
            try:
                async with self.session.get(self.FEED_URL, headers=self.headers, timeout=ClientTimeout(total=10)) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        items = data.get("items", [])
                        # 更新缓存
                        self.cache = items
                        self.cache_timestamp = current_time
                        return items
                    else:
                        print(f"Failed to fetch AppImage feed: HTTP {resp.status}")
                        return []
            except Exception as e:
                print(f"Exception while fetching AppImage feed: {e}")
                return []
        
    def _extract_download_url(self, links):
        """从 links 列表中找到 type 为 Download 的 url"""
        if not links:
            return ""
        for link in links:
            if link.get("type") == "Download":
                return link.get("url", "")
        return ""
    
    def is_installed(self, app_name: str) -> bool:
        # 由于 AppImage 没有统一的安装方式，我们只能通过一些 heuristics 来判断是否安装
        # 这里我们简单地检查用户的 home 目录下是否存在以 app_name 命名的 AppImage 文件
        # 注意：这只是一个非常粗糙的判断方法，可能会有误判
        apps_dir = Path.home() / "Applications"
        if not apps_dir.exists():
            return False
        return any(app_name.lower() in f.name.lower() for f in apps_dir.glob("*.AppImage"))

    async def search(self, query: str) -> List[Dict]:
        if not query or len(query) < 2:
            return []
        
        feed_items = await self._fetch_feed()
        query_lower = query.lower()
        
        # 1. 过滤匹配项
        matched_items = [
            item for item in feed_items 
            if query_lower in item.get("name", "").lower() 
            or query_lower in item.get("description", "").lower()
        ]
        
        if not matched_items:
            return []

        # 2. 并行检查安装状态（通过线程池）
        loop = asyncio.get_event_loop()
        tasks = [
            loop.run_in_executor(self.executor, self.is_installed, item.get("name", ""))
            for item in matched_items
        ]
        
        # 这一步执行后，installed_statuses 的顺序与 matched_items 完全一致
        installed_statuses = await asyncio.gather(*tasks)

        # 3. 组装结果：使用 zip 将数据和对应的安装状态合并
        results = []
        for item, is_inst in zip(matched_items, installed_statuses):
            results.append({
                "name": item.get("name", ""),
                "last_version": item.get("version", ""),
                "description": item.get("description", ""),
                "source": self.name,
                "votes": 0,
                "installed": is_inst,  # 这里的 is_inst 是具体的 True 或 False
                "url": self._extract_download_url(item.get("links", []))  # 提取下载链接
            })
        
        return results