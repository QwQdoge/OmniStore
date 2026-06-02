import asyncio
import aiohttp
import subprocess
import os
from pathlib import Path
from typing import List, Dict, Any, Optional
from core.sources.base import UnifiedSource

class AppImageSource(UnifiedSource):
    FEED_URL = "https://appimage.github.io/feed.json"
    headers = {"User-Agent": "Omnistore/0.1"}

    def __init__(self, session: aiohttp.ClientSession, config_manager: Any, weight: float = 1.0):
        super().__init__(name="AppImage", weight=weight)
        self.session = session
        self.cm = config_manager
        self.cache: List[Dict] = []
        self.cache_timestamp = 0
        self.cache_duration = 3600
        self.lock = asyncio.Lock()

    async def _fetch_feed(self) -> List[Dict]:
        async with self.lock:
            current_time = asyncio.get_event_loop().time()
            if self.cache and (current_time - self.cache_timestamp < self.cache_duration):
                return self.cache

            feeds = [self.FEED_URL] + self.cm.get("custom_repos.appimage", [])
            tasks = []
            for url in feeds:
                tasks.append(self.session.get(url, headers=self.headers, timeout=aiohttp.ClientTimeout(total=8)))

            responses = await asyncio.gather(*tasks, return_exceptions=True)
            merged_items = []
            seen_names = set()

            for resp in responses:
                if isinstance(resp, aiohttp.ClientResponse) and resp.status == 200:
                    try:
                        data = await resp.json()
                        items = data.get("items", [])
                        for item in items:
                            name = item.get("name")
                            if name and name not in seen_names:
                                seen_names.add(name)
                                merged_items.append(item)
                    except Exception: pass

            self.cache = merged_items
            self.cache_timestamp = current_time
            return merged_items

    def _is_installed(self, app_name: str) -> bool:
        apps_dir = Path.home() / "Applications"
        if not apps_dir.exists(): return False
        return any(app_name.lower() in f.name.lower() for f in apps_dir.glob("*.AppImage"))

    async def search(self, query: str) -> List[Dict[str, Any]]:
        feed_items = await self._fetch_feed()
        query_lower = query.lower()
        results = []
        for item in feed_items:
            name = item.get("name", "")
            desc = item.get("description", "")
            if query_lower in name.lower() or query_lower in desc.lower():
                is_inst = self._is_installed(name)
                download_url = ""
                for link in item.get("links", []):
                    if link.get("type") == "Download":
                        download_url = link.get("url", "")
                        break

                results.append({
                    "name": name,
                    "last_version": item.get("version", ""),
                    "description": desc,
                    "source": "AppImage",
                    "installed": is_inst,
                    "url": download_url,
                    "variants": [{
                        "source": "AppImage",
                        "url": download_url,
                        "installed": is_inst
                    }]
                })
        return results

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        name = package.get("name")
        url = package.get("url")
        if not url:
            if callback: await callback("[ERROR] No download URL for AppImage.")
            return False

        apps_dir = Path.home() / "Applications"
        apps_dir.mkdir(parents=True, exist_ok=True)
        dest = apps_dir / f"{name}.AppImage"

        if callback: await callback(f"[INFO] Downloading {name} AppImage from {url}...")

        try:
            async with self.session.get(url) as resp:
                if resp.status != 200:
                    if callback: await callback(f"[ERROR] Download failed: HTTP {resp.status}")
                    return False

                total = int(resp.headers.get('content-length', 0))
                downloaded = 0
                with open(dest, 'wb') as f:
                    async for chunk in resp.content.iter_chunked(8192):
                        f.write(chunk)
                        downloaded += len(chunk)
                        if total > 0 and callback:
                            progress = int(downloaded / total * 100)
                            await callback(f"[PROGRESS] {progress}")

            # Make executable
            dest.chmod(0o755)
            if callback: await callback(f"[INFO] Successfully installed {name} to {dest}")
            return True
        except Exception as e:
            if callback: await callback(f"[ERROR] AppImage installation failed: {e}")
            return False

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        name = package.get("name")
        apps_dir = Path.home() / "Applications"
        found = list(apps_dir.glob(f"*{name}*.AppImage"))
        if not found:
            if callback: await callback(f"[ERROR] {name} AppImage not found in {apps_dir}")
            return False

        for f in found:
            try:
                f.unlink()
                if callback: await callback(f"[INFO] Removed {f}")
            except Exception as e:
                if callback: await callback(f"[ERROR] Failed to remove {f}: {e}")
                return False
        return True

    async def launch(self, package: Dict[str, Any]) -> bool:
        name = package.get("name")
        apps_dir = Path.home() / "Applications"
        found = list(apps_dir.glob(f"*{name}*.AppImage"))
        if found:
            subprocess.Popen([str(found[0])], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        apps_dir = Path.home() / "Applications"
        subprocess.Popen(["xdg-open", str(apps_dir)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        return {"name": package_id, "source": "AppImage"}

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        return None
