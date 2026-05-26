import aiohttp
import asyncio
import json
import random
from typing import List, Dict
from core.habit_tracker import HabitTracker

class RecommendationManager:
    def __init__(self, session: aiohttp.ClientSession):
        self.session = session
        self.habit_tracker = HabitTracker()
        self.flathub_popular_url = "https://flathub.org/api/v2/collection/popular"
        self.flathub_trending_url = "https://flathub.org/api/v2/collection/trending"

    async def get_recommendations(self) -> List[Dict]:
        """Fetch recommendations from external sources and mix with user habits"""
        try:
            # Concurrent fetch from Flathub
            async with self.session.get(self.flathub_popular_url, timeout=10) as resp:
                popular_data = await resp.json() if resp.status == 200 else {"hits": []}

            async with self.session.get(self.flathub_trending_url, timeout=10) as resp:
                trending_data = await resp.json() if resp.status == 200 else {"hits": []}

            popular = popular_data.get("hits", [])
            trending = trending_data.get("hits", [])

            # Combine and de-duplicate
            raw_apps = {app['app_id']: app for app in (popular + trending) if 'app_id' in app}.values()

            # Convert to OmniArch format
            recommended = []
            for app in raw_apps:
                recommended.append({
                    "name": app.get("name", "Unknown"),
                    "id": app.get("app_id"),
                    "description": app.get("summary", ""),
                    "source": "Flatpak",
                    "icon": app.get("iconDesktopUrl") or app.get("iconMobileUrl"),
                    "installed": False, # Will be checked by frontend or further logic
                    "primary_source": "Flatpak",
                    "version": "N/A",
                    "variants": [{"source": "Flatpak", "version": "N/A"}]
                })

            # Simple shuffle for "refresh" effect
            random.shuffle(recommended)

            # Fetch screenshots and icons for the top 10 recommended apps to ensure cards have visuals
            async def _enrich_item(item):
                details = await self.get_details(item['id'])
                if details:
                    item['icon'] = details.get('icon') or item.get('icon')
                    item['screenshots'] = details.get('screenshots') or []
                    item['description'] = details.get('description') or item.get('description')

            enrich_tasks = [_enrich_item(app) for app in recommended[:15]]
            await asyncio.gather(*enrich_tasks)

            # Limit results
            return recommended[:20]

        except Exception as e:
            print(f"[RecommendationManager] Error: {e}")
            return [
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
                },
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
                },
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
                },
                {
                    "name": "GIMP",
                    "id": "org.gimp.GIMP",
                    "description": "GNU Image Manipulation Program.",
                    "source": "Flatpak",
                    "icon": "https://dl.flathub.org/media/org/gimp/GIMP/cb137beee095a0a382e21297e682ff96/icons/128x128@2/org.gimp.GIMP.png",
                    "installed": False,
                    "primary_source": "Flatpak",
                    "version": "N/A",
                    "variants": [{"source": "Flatpak", "version": "N/A"}],
                    "screenshots": []
                },
                {
                    "name": "OBS Studio",
                    "id": "com.obsproject.Studio",
                    "description": "Free and open source software for video recording and live streaming.",
                    "source": "Flatpak",
                    "icon": "https://dl.flathub.org/media/com/obsproject/Studio/3565f9730591f4fa59d1a3c631e84617/icons/128x128@2/com.obsproject.Studio.png",
                    "installed": False,
                    "primary_source": "Flatpak",
                    "version": "N/A",
                    "variants": [{"source": "Flatpak", "version": "N/A"}],
                    "screenshots": []
                }
            ]

    async def get_details(self, app_id: str) -> Dict:
        """Fetch rich details for a specific app (Flathub API)"""
        url = f"https://flathub.org/api/v2/appstream/{app_id}"
        try:
            async with self.session.get(url, timeout=10) as resp:
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

                    return {
                        "name": data.get("name"),
                        "description": data.get("description"),
                        "screenshots": screenshots,
                        "developer": data.get("developer_name"),
                        "homepage": data.get("urls", {}).get("homepage"),
                        "license": data.get("project_license"),
                        "icon": icon
                    }
        except Exception as e:
            print(f"[RecommendationManager] Detail Error: {e}")
        return {}

    async def find_metadata(self, name: str) -> Dict:
        """Try to find metadata (icon, description) for a package name by searching Flathub"""
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
                            app_id = hit.get("app_id", "").lower()
                            if hit_name == name.lower() or app_id == name.lower() or app_id.endswith(f".{name.lower()}"):
                                return await self.get_details(hit.get("app_id"))
        except Exception as e:
            print(f"[RecommendationManager] Find Metadata Error: {e}")
        return {}
