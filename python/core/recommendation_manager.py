import aiohttp
import asyncio
import json
import random
import time
from pathlib import Path
from typing import List, Dict, Any, Optional
from core.habit_tracker import HabitTracker

class RecommendationManager:
    def __init__(self, session: aiohttp.ClientSession, habit_tracker: HabitTracker = None):
        self.session = session
        self.habit_tracker = habit_tracker or HabitTracker()
        self.flathub_popular_url = "https://flathub.org/api/v2/collection/popular"
        self.flathub_trending_url = "https://flathub.org/api/v2/collection/trending"
        self.cache_dir = Path.home() / ".cache" / "omnistore"
        self.cache_path = self.cache_dir / "recommendations.json"
        self.metadata_cache_path = self.cache_dir / "metadata_cache.json"
        self._metadata_cache = self._load_metadata_cache()
        # ⚡ Optimization: flags for coalesced saving
        self._is_saving = False
        self._needs_another_save = False
        # ⚡ Optimization: track ongoing async tasks to deduplicate concurrent requests
        self._pending_tasks = {}

    def _load_metadata_cache(self) -> Dict[str, Any]:
        """Load metadata cache from disk"""
        if not self.metadata_cache_path.exists():
            return {"app_details": {}, "name_mapping": {}}
        try:
            with open(self.metadata_cache_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {"app_details": {}, "name_mapping": {}}

    async def _save_metadata_cache(self):
        """Save metadata cache to disk asynchronously with coalescing"""
        if self._is_saving:
            self._needs_another_save = True
            return

        self._is_saving = True
        self._needs_another_save = False

        try:
            self.cache_dir.mkdir(parents=True, exist_ok=True)

            # Use run_in_executor to avoid blocking the event loop with synchronous file I/O
            def _write(data_snapshot):
                # Atomically write using a temporary file
                tmp_path = self.metadata_cache_path.with_suffix(".tmp")
                with open(tmp_path, "w", encoding="utf-8") as f:
                    json.dump(data_snapshot, f, ensure_ascii=False)
                tmp_path.replace(self.metadata_cache_path)

            # ⚡ Snapshot the data to avoid "dict changed size" during JSON serialization in the executor
            # We use a deeper snapshot for the inner dictionaries as well.
            data_snapshot = {
                "app_details": {k: v.copy() if isinstance(v, dict) else v for k, v in self._metadata_cache.get("app_details", {}).items()},
                "name_mapping": {k: v.copy() if isinstance(v, dict) else v for k, v in self._metadata_cache.get("name_mapping", {}).items()}
            }

            await asyncio.get_event_loop().run_in_executor(None, _write, data_snapshot)
        except Exception as e:
            import sys
            sys.stderr.write(f"[RecommendationManager] Metadata Cache Save Error: {e}\n")
        finally:
            self._is_saving = False
            if self._needs_another_save:
                # Schedule another save if needed
                asyncio.create_task(self._save_metadata_cache())

    async def _safe_print_error(self, msg: str):
        import sys
        sys.stderr.write(f"{msg}\n")

    def _load_cache(self) -> Optional[Dict[str, List[Dict]]]:
        """Load recommendations from cache if not expired"""
        if not self.cache_path.exists():
            return None
        try:
            with open(self.cache_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                # Cache valid for 1 hour (3600 seconds)
                if time.time() - data.get("timestamp", 0) < 3600:
                    return data.get("recommendations")
        except Exception:
            pass
        return None

    def _save_cache(self, recommendations: Dict[str, List[Dict]]):
        """Save recommendations to cache"""
        try:
            self.cache_dir.mkdir(parents=True, exist_ok=True)
            with open(self.cache_path, "w", encoding="utf-8") as f:
                json.dump({
                    "timestamp": time.time(),
                    "recommendations": recommendations
                }, f, ensure_ascii=False)
        except Exception as e:
            import sys
            sys.stderr.write(f"[RecommendationManager] Cache Save Error: {e}\n")

    async def _fetch_collection(self, url: str) -> List[Dict]:
        """Fetch a collection of apps from Flathub"""
        try:
            # Flathub V2 API requires specific headers sometimes
            headers = {
                "Accept": "application/json",
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) OmniStore/0.1.0"
            }
            async with self.session.get(url, timeout=15, headers=headers) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    hits = data.get("hits", [])
                    apps = []
                    for app in hits:
                        if not isinstance(app, dict): continue
                        apps.append({
                            "name": app.get("name", "Unknown"),
                            "id": app.get("app_id"),
                            "description": app.get("summary", ""),
                            "source": "Flatpak",
                            "icon": app.get("iconDesktopUrl") or app.get("iconMobileUrl"),
                            "installed": False,
                            "primary_source": "Flatpak",
                            "version": "N/A",
                            "variants": [{"source": "Flatpak", "version": "N/A"}]
                        })
                    return apps
        except Exception as e:
            import sys
            sys.stderr.write(f"[RecommendationManager] Collection Fetch Error ({url}): {e}\n")
        return []

    async def get_recommendations(self, force_refresh: bool = False, sources: List = None) -> Dict[str, List[Dict]]:
        """Fetch categorized recommendations"""
        if not force_refresh:
            cached = self._load_cache()
            if cached:
                return cached

        try:
            # 1. Fetch collections concurrently
            popular_task = self._fetch_collection(self.flathub_popular_url)
            trending_task = self._fetch_collection(self.flathub_trending_url)

            popular, trending = await asyncio.gather(popular_task, trending_task)

            # 2. Personalization (For You)
            for_you = []
            tags = self.habit_tracker.get_recommendation_tags()
            if tags:
                # Search for apps matching tags
                search_url = "https://flathub.org/api/v2/search"
                tag_tasks = []
                for tag in tags[:3]: # Limit to top 3 tags to avoid over-requesting
                    tag_tasks.append(self.session.post(search_url, json={"query": tag}, timeout=5))

                search_resps = await asyncio.gather(*tag_tasks, return_exceptions=True)
                for resp in search_resps:
                    if isinstance(resp, aiohttp.ClientResponse) and resp.status == 200:
                        search_data = await resp.json()
                        hits = search_data.get("hits", [])
                        for hit in hits[:5]:
                            for_you.append({
                                "name": hit.get("name", "Unknown"),
                                "id": hit.get("app_id"),
                                "description": hit.get("summary", ""),
                                "source": "Flatpak",
                                "icon": hit.get("iconDesktopUrl") or hit.get("iconMobileUrl"),
                                "installed": False,
                                "primary_source": "Flatpak",
                                "version": "N/A",
                                "variants": [{"source": "Flatpak", "version": "N/A"}]
                            })

            # 3. Enrich top items for each category
            async def _enrich_item(item):
                if not item.get('id'): return
                details = await self.get_details(item['id'])
                if details:
                    item['icon'] = details.get('icon') or item.get('icon')
                    item['screenshots'] = details.get('screenshots') or []
                    item['description'] = details.get('description') or item.get('description')

            # Enrich first few items to ensure quality
            # Deduplication of network requests is handled internally by get_details coalescing
            enrich_list = popular[:5] + trending[:5] + for_you[:5]
            await asyncio.gather(*[_enrich_item(item) for item in enrich_list])

            # Deduplicate For You from others
            seen_ids = {app['id'] for app in popular + trending}
            for_you = [app for app in for_you if app['id'] not in seen_ids]

            result = {
                "featured": popular[:10],
                "trending": trending[:15],
                "for_you": for_you[:15]
            }

            # Merge recommendations from other sources
            if sources:
                tasks = [src.get_recommendations() for src in sources if hasattr(src, "get_recommendations")]
                source_recs = await asyncio.gather(*tasks, return_exceptions=True)
                for rec in source_recs:
                    if isinstance(rec, dict):
                        result["featured"].extend(rec.get("featured", []))
                        result["trending"].extend(rec.get("trending", []))
                        result["for_you"].extend(rec.get("for_you", []))

            self._save_cache(result)
            return result

        except Exception as e:
            import sys
            sys.stderr.write(f"[RecommendationManager] Error: {e}\n")
            # Fallback data in the correct structure
            fallback = {
                "featured": [
                    {
                        "name": "Firefox",
                        "id": "org.mozilla.firefox",
                        "description": "Safe, fast, and private web browser.",
                        "source": "Flatpak",
                        "icon": "https://dl.flathub.org/media/org/mozilla/firefox/d39c09bd9601d2a138bbdb6a9134015f/icons/128x128@2/org.mozilla.firefox.png",
                        "installed": False,
                        "primary_source": "Flatpak",
                        "version": "N/A",
                        "variants": [{"source": "Flatpak", "version": "N/A"}],
                        "screenshots": []
                    }
                ],
                "trending": [
                    {
                        "name": "VLC",
                        "id": "org.videolan.VLC",
                        "description": "VLC media player, the open source multimedia player.",
                        "source": "Flatpak",
                        "icon": "https://dl.flathub.org/media/org/videolan/VLC/d0b904df90e3cd2958742b65109fd268/icons/128x128@2/org.videolan.VLC.png",
                        "installed": False,
                        "primary_source": "Flatpak",
                        "version": "N/A",
                        "variants": [{"source": "Flatpak", "version": "N/A"}],
                        "screenshots": []
                    }
                ],
                "for_you": [
                    {
                        "name": "Visual Studio Code",
                        "id": "com.visualstudio.code",
                        "description": "Visual Studio Code. Code editing. Redefined.",
                        "source": "Flatpak",
                        "icon": "https://dl.flathub.org/media/com/visualstudio/code/94318c642646d1bf7fa780d603a110a3/icons/128x128@2/com.visualstudio.code.png",
                        "installed": False,
                        "primary_source": "Flatpak",
                        "version": "N/A",
                        "variants": [{"source": "Flatpak", "version": "N/A"}],
                        "screenshots": []
                    }
                ]
            }
            return fallback

    async def get_category_apps(self, category: str) -> List[Dict]:
        """Fetch popular apps for a specific category from Flathub"""
        url = f"https://flathub.org/api/v2/collection/category/{category}"
        try:
            apps = await self._fetch_collection(url)
            # Enrich the top 10 for better UI display
            await asyncio.gather(*[self._enrich_item(item) for item in apps[:10]])
            return apps
        except Exception as e:
            import sys
            sys.stderr.write(f"[RecommendationManager] Category apps error: {e}\n")
            return []

    async def _enrich_item(self, item):
        if not item.get('id'): return
        details = await self.get_details(item['id'])
        if details:
            item['icon'] = details.get('icon') or item.get('icon')
            item['screenshots'] = details.get('screenshots') or []
            item['description'] = details.get('description') or item.get('description')

    async def get_details(self, app_id: str, use_network: bool = True) -> Dict:
        """Fetch rich details for a specific app (Flathub API) with caching and deduplication"""
        # 1. Check cache (TTL 24 hours)
        cache_entry = self._metadata_cache.get("app_details", {}).get(app_id)
        if cache_entry and time.time() - cache_entry.get("timestamp", 0) < 86400:
            return cache_entry.get("data", {})

        if not use_network:
            return {}

        # 2. Deduplicate concurrent requests for the same app_id
        if app_id in self._pending_tasks:
            return await self._pending_tasks[app_id]

        task = asyncio.create_task(self._get_details_impl(app_id))
        self._pending_tasks[app_id] = task
        try:
            return await task
        finally:
            self._pending_tasks.pop(app_id, None)

    async def _get_details_impl(self, app_id: str) -> Dict:
        """Internal implementation for network fetch of app details"""
        url = f"https://flathub.org/api/v2/appstream/{app_id}"
        try:
            headers = {
                "Accept": "application/json",
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) OmniStore/0.1.0"
            }
            async with self.session.get(url, timeout=10, headers=headers) as resp:
                if resp.status == 200:
                    data = await resp.json()

                    # Extract high-res icon
                    icon = None
                    icons = data.get("icons", [])
                    if icons:
                        # Prefer remote icons with highest scale/width
                        icons.sort(key=lambda x: (x.get("width", 0) * (x.get("scale", 1) or 1)), reverse=True)
                        icon = icons[0].get("url")

                    # Extract screenshots
                    screenshots = []
                    for s in data.get("screenshots", []):
                        # Screenshots in V2 often have a 'sizes' list
                        sizes = s.get("sizes", [])
                        if sizes:
                            # Prefer largest size or 'orig'
                            sizes.sort(key=lambda x: int(x.get("width", 0)) if str(x.get("width", 0)).isdigit() else 0, reverse=True)
                            screenshots.append(sizes[0].get("src"))
                        else:
                            # Fallback to old format
                            for size, details in s.items():
                                if isinstance(details, dict) and "url" in details:
                                    screenshots.append(details["url"])
                                    break
                                elif isinstance(details, str) and details.startswith("http"):
                                    screenshots.append(details)
                                    break

                    result = {
                        "name": data.get("name"),
                        "description": data.get("description"),
                        "screenshots": screenshots,
                        "developer": data.get("developer_name"),
                        "homepage": data.get("urls", {}).get("homepage"),
                        "license": data.get("project_license"),
                        "icon": icon
                    }

                    # 3. Save to cache
                    self._metadata_cache["app_details"][app_id] = {
                        "timestamp": time.time(),
                        "data": result
                    }
                    await self._save_metadata_cache()
                    return result
        except Exception as e:
            import sys
            sys.stderr.write(f"[RecommendationManager] Detail Error: {e}\n")
        return {}

    async def find_metadata(self, name: str, use_network: bool = True) -> Dict:
        """Try to find metadata (icon, description) for a package name with caching and deduplication"""
        name_lower = name.lower()
        # 1. Check name mapping cache (TTL 24 hours)
        mapping_entry = self._metadata_cache.get("name_mapping", {}).get(name_lower)
        if mapping_entry and time.time() - mapping_entry.get("timestamp", 0) < 86400:
            app_id = mapping_entry.get("app_id")
            if app_id:
                return await self.get_details(app_id, use_network=use_network)
            else:
                # Negative cache hit (known not to have metadata on Flathub)
                return {}

        if not use_network:
            return {}

        # 2. Deduplicate concurrent searches for the same name
        task_key = f"search:{name_lower}"
        if task_key in self._pending_tasks:
            return await self._pending_tasks[task_key]

        task = asyncio.create_task(self._find_metadata_impl(name))
        self._pending_tasks[task_key] = task
        try:
            return await task
        finally:
            self._pending_tasks.pop(task_key, None)

    async def _find_metadata_impl(self, name: str) -> Dict:
        """Internal implementation for finding metadata via Flathub search"""
        name_lower = name.lower()
        search_url = "https://flathub.org/api/v2/search"
        try:
            async with self.session.post(search_url, json={"query": name}, timeout=5) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    hits = data.get("hits", [])
                    if hits:
                        # Find the best match
                        for hit in hits:
                            hit_name = hit.get("name", "").lower()
                            hit_app_id = hit.get("app_id", "").lower()
                            if hit_name == name_lower or hit_app_id == name_lower or hit_app_id.endswith(f".{name_lower}"):
                                # 3. Save mapping to cache
                                self._metadata_cache["name_mapping"][name_lower] = {
                                    "timestamp": time.time(),
                                    "app_id": hit.get("app_id")
                                }
                                # Save mapping immediately so it's available for other concurrent searches
                                await self._save_metadata_cache()
                                return await self.get_details(hit.get("app_id"))

                    # 4. Negative caching: no hits found, store None to avoid repeated searches
                    self._metadata_cache["name_mapping"][name_lower] = {
                        "timestamp": time.time(),
                        "app_id": None
                    }
                    await self._save_metadata_cache()
        except Exception as e:
            import sys
            sys.stderr.write(f"[RecommendationManager] Find Metadata Error: {e}\n")
        return {}
