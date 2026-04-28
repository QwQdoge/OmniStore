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

            # Limit results
            return recommended[:20]

        except Exception as e:
            print(f"[RecommendationManager] Error: {e}")
            return []

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
