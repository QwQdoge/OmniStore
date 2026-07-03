import asyncio
import aiohttp
import subprocess
import os
import re
import shutil
from urllib.parse import urlparse
from urllib.request import url2pathname
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
        self.cache_timestamp: float = 0.0
        self.cache_duration = 3600
        self.lock = asyncio.Lock()

    def config_schema(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "feeds": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Additional AppImage feed URLs.",
                },
                "local_dirs": {
                    "type": "array",
                    "items": {"type": "string"},
                    "default": ["~/Applications"],
                    "description": "Directories scanned for local AppImage files.",
                },
            },
        }

    async def _fetch_feed(self) -> List[Dict]:
        async with self.lock:
            current_time = asyncio.get_event_loop().time()
            if self.cache and (current_time - self.cache_timestamp < self.cache_duration):
                return self.cache

            feeds = [self.FEED_URL] + (self.cm.get("custom_repos.appimage", []) or [])

            async def _fetch_one(url):
                try:
                    async with self.session.get(url, headers=self.headers, timeout=aiohttp.ClientTimeout(total=8)) as resp:
                        if resp.status == 200:
                            return await resp.json()
                except Exception:
                    pass
                return None

            results = await asyncio.gather(*[_fetch_one(url) for url in feeds], return_exceptions=True)
            merged_items = []
            seen_names = set()

            for data in results:
                if isinstance(data, dict):
                    items = data.get("items")
                    if isinstance(items, list):
                        for item in items:
                            name = item.get("name")
                            if name and name not in seen_names:
                                seen_names.add(name)
                                merged_items.append(item)

            self.cache = merged_items
            self.cache_timestamp = current_time
            return merged_items

    def _is_installed(self, app_name: str) -> bool:
        apps_dir = Path.home() / "Applications"
        if not apps_dir.exists(): return False
        return any(app_name.lower() in f.name.lower() for f in apps_dir.glob("*.AppImage"))

    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:
        feed_items = await self._fetch_feed()
        query_lower = query.lower()
        results = []
        for item in feed_items:
            name = item.get("name", "")
            desc = item.get("description", "")
            if query_lower in name.lower() or query_lower in desc.lower():
                is_inst = self._is_installed(name)
                download_url = ""
                links = item.get("links") or []
                for link in links:
                    if not isinstance(link, dict): continue
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

    async def _resolve_github_appimage(self, url: str, callback=None) -> str:
        """If the url is a GitHub repository/release page, resolve it to the latest AppImage binary asset URL."""
        if "github.com" not in url:
            return url
        if url.lower().endswith(".appimage"):
            return url

        match = re.search(r"github\.com/([^/]+)/([^/]+)", url)
        if not match:
            return url

        owner = match.group(1)
        repo = match.group(2).split("/")[0]

        api_url = f"https://api.github.com/repos/{owner}/{repo}/releases/latest"
        headers = {"Accept": "application/vnd.github.v3+json", "User-Agent": "Omnistore/0.1"}

        pat = self.cm.get("github_store.pat")
        if pat:
            headers["Authorization"] = f"token {pat}"

        if callback:
            await callback(f"[INFO] Resolving GitHub release asset: {owner}/{repo}...")

        try:
            async with self.session.get(api_url, headers=headers) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    assets = data.get("assets", [])
                    appimage_assets = [
                        a for a in assets 
                        if a.get("name", "").lower().endswith(".appimage")
                    ]
                    if not appimage_assets:
                        return url

                    for a in appimage_assets:
                        name_lower = a.get("name", "").lower()
                        if "x86_64" in name_lower or "amd64" in name_lower or "x64" in name_lower:
                            resolved = a.get("browser_download_url")
                            if callback:
                                await callback(f"[INFO] Resolved architecture matching asset: {a.get('name')}")
                            return resolved

                    resolved = appimage_assets[0].get("browser_download_url")
                    if callback:
                        await callback(f"[INFO] Resolved first available asset: {appimage_assets[0].get('name')}")
                    return resolved
        except Exception as e:
            if callback:
                await callback(f"[INFO] Failed to resolve GitHub URL ({e}). Attempting direct download.")
        return url

    def _create_desktop_entry(self, name: str, exec_path: Path):
        desktop_dir = Path.home() / ".local/share/applications"
        desktop_dir.mkdir(parents=True, exist_ok=True)
        desktop_file = desktop_dir / f"{name.lower()}.desktop"
        content = f"""[Desktop Entry]
Version=1.0
Type=Application
Name={name}
Comment=Installed via Omnistore
Exec="{exec_path}" %U
Icon={name.lower()}
Terminal=false
Categories=Utility;Application;
"""
        with open(desktop_file, "w") as f:
            f.write(content)

    def _delete_desktop_entry(self, name: str):
        desktop_file = Path.home() / f".local/share/applications/{name.lower()}.desktop"
        if desktop_file.exists():
            try:
                desktop_file.unlink()
            except Exception:
                pass

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        callback = self._async_callback(callback)
        name = str(package.get("name") or "")
        url = package.get("url")
        if not name or not url:
            if callback: await callback("[ERROR] Missing package name or download URL for AppImage.")
            return False

        apps_dir = Path.home() / "Applications"
        apps_dir.mkdir(parents=True, exist_ok=True)
        dest = apps_dir / f"{name}.AppImage"

        url = await self._resolve_github_appimage(url, callback)

        if callback: await callback(f"[INFO] Downloading {name} AppImage from {url}...")

        try:
            parsed = urlparse(url)
            if parsed.scheme == "file":
                shutil.copy2(Path(url2pathname(parsed.path)), dest)
                if callback:
                    await callback("[PROGRESS] 100")
            elif parsed.scheme == "" and Path(url).exists():
                shutil.copy2(Path(url), dest)
                if callback:
                    await callback("[PROGRESS] 100")
            else:
                async with self.session.get(url) as resp:
                    if resp.status != 200:
                        if callback: await callback(f"[ERROR] Download failed: HTTP {resp.status}")
                        return False

                    total = int(resp.headers.get('content-length', 0))
                    downloaded = 0
                    last_percent = -1
                    with open(dest, 'wb') as f:
                        async for chunk in resp.content.iter_chunked(8192):
                            f.write(chunk)
                            downloaded += len(chunk)
                            if total > 0 and callback:
                                progress = int(downloaded / total * 100)
                                if progress > last_percent:
                                    await callback(f"[PROGRESS] {progress}")
                                    last_percent = progress

            dest.chmod(0o755)
            try:
                self._create_desktop_entry(name, dest)
                if callback: await callback(f"[INFO] Created desktop menu entry for {name}")
            except Exception as e:
                if callback: await callback(f"[INFO] Failed to create desktop entry: {e}")

            if callback: await callback(f"[INFO] Successfully installed {name} to {dest}")
            return True
        except Exception as e:
            if callback: await callback(f"[ERROR] AppImage installation failed: {e}")
            return False

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        callback = self._async_callback(callback)
        name = str(package.get("name") or "")
        if not name:
            if callback: await callback("[ERROR] Missing package name for AppImage uninstall.")
            return False
        apps_dir = Path.home() / "Applications"
        found = list(apps_dir.glob(f"*{name}*.AppImage"))

        self._delete_desktop_entry(name)
        if callback: await callback(f"[INFO] Removed desktop entry for {name}")

        if not found:
            fallback = apps_dir / f"{name}.AppImage"
            if fallback.exists():
                found = [fallback]

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
        from core.subprocess_utils import safe_subprocess
        found = list(apps_dir.glob(f"*{name}*.AppImage"))
        if found:
            async with safe_subprocess(str(found[0]), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL):
                return True
        return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        apps_dir = Path.home() / "Applications"
        from core.subprocess_utils import safe_subprocess
        async with safe_subprocess("xdg-open", str(apps_dir), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL):
            return True

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        return {"name": package_id, "source": "AppImage"}

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        return None

    async def list_installed(self) -> List[Dict[str, Any]]:
        apps_dir = Path.home() / "Applications"
        if not apps_dir.exists():
            return []
        results: List[Dict[str, Any]] = []
        for path in sorted(apps_dir.glob("*.AppImage")):
            size = await self.get_size({"name": path.stem, "path": str(path)})
            results.append({
                "name": path.stem,
                "id": str(path),
                "primary_source": "AppImage",
                "source": "AppImage",
                "managed": True,
                "installed": True,
                "description": f"Local AppImage at {path}",
                "version": "Local",
                "url": path.as_uri(),
                **size,
                "variants": [{"source": "AppImage", "id": str(path), "url": path.as_uri(), "installed": True, "managed": True, **size}],
            })
        return results

    async def get_size(self, package: Dict[str, Any]) -> Dict[str, Any]:
        raw_path = package.get("path") or package.get("id")
        try:
            path = Path(str(raw_path))
            if path.exists() and path.is_file():
                return {
                    "download_size": None,
                    "installed_size": self._format_bytes(path.stat().st_size),
                    "disk_size": path.stat().st_size,
                    "size_confidence": "exact",
                    "size_source": "filesystem scan",
                }
        except Exception:
            pass
        return await super().get_size(package)

    def _format_bytes(self, size: int) -> str:
        units = ["B", "KB", "MB", "GB", "TB"]
        value = float(size)
        for unit in units:
            if value < 1024 or unit == units[-1]:
                return f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"
            value /= 1024
