import json
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

class CacheManager:
    def __init__(self):
        self.cache_dir = Path.home() / ".cache" / "omnistore"
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.installed_cache_path = self.cache_dir / "installed_packages.json"

    def get_installed_packages(self) -> Optional[List[Dict[str, Any]]]:
        """Get installed packages from cache if not expired (default 1 hour)."""
        if not self.installed_cache_path.exists():
            return None

        try:
            with open(self.installed_cache_path, "r", encoding="utf-8") as f:
                data = json.load(f)

            # Check expiration (1 hour = 3600 seconds)
            if time.time() - data.get("timestamp", 0) > 3600:
                return None

            return data.get("packages")
        except Exception:
            return None

    def save_installed_packages(self, packages: List[Dict[str, Any]]):
        """Save installed packages to cache."""
        try:
            data = {
                "timestamp": time.time(),
                "packages": packages
            }
            with open(self.installed_cache_path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False)
        except Exception as e:
            print(f"[Cache] Save Error: {e}")

    def invalidate_installed_cache(self):
        """Invalidate the installed packages cache."""
        if self.installed_cache_path.exists():
            try:
                self.installed_cache_path.unlink()
            except Exception:
                pass
