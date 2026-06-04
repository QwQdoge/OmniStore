import json
from pathlib import Path
from typing import Dict, Any

import asyncio

class HabitTracker:
    def __init__(self):
        self.data_dir = Path.home() / ".config" / "omnistore"
        self.data_path = self.data_dir / "user_habits.json"
        self.habits = self._load_habits()
        # ⚡ Optimization: flags for coalesced saving
        self._is_saving = False
        self._needs_another_save = False

    def _load_habits(self) -> Dict[str, Any]:
        if not self.data_path.exists():
            return {
                "search_history": {},  # { "query": count }
                "install_history": {}, # { "package_name": { "source": str, "count": int } }
                "source_preference": { "Native": 0, "AUR": 0, "Flatpak": 0, "AppImage": 0 }
            }
        try:
            with open(self.data_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {
                "search_history": {},
                "install_history": {},
                "source_preference": { "Native": 0, "AUR": 0, "Flatpak": 0, "AppImage": 0 }
            }

    def _save_habits(self):
        """
        ⚡ Optimization: Save habits to disk asynchronously with coalescing.
        Uses a flag-based system to prevent race conditions and redundant I/O.
        """
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            # Fallback for synchronous execution (e.g. CLI exit)
            self.data_dir.mkdir(parents=True, exist_ok=True)
            with open(self.data_path, "w", encoding="utf-8") as f:
                json.dump(self.habits, f, ensure_ascii=False, indent=2)
            return

        if self._is_saving:
            self._needs_another_save = True
            return

        self._is_saving = True
        self._needs_another_save = False

        async def _save_task():
            try:
                # Use run_in_executor for disk I/O
                def _write(data_snapshot):
                    self.data_dir.mkdir(parents=True, exist_ok=True)
                    tmp_path = self.data_path.with_suffix(".tmp")
                    with open(tmp_path, "w", encoding="utf-8") as f:
                        json.dump(data_snapshot, f, ensure_ascii=False, indent=2)
                    tmp_path.replace(self.data_path)

                # ⚡ Snapshot using dict() to avoid blocking the main thread with full serialization
                # and to avoid "dict changed size" during the background write.
                snapshot = {k: {ik: iv.copy() if isinstance(iv, dict) else iv for ik, iv in v.items()} if isinstance(v, dict) else v for k, v in self.habits.items()}
                await loop.run_in_executor(None, _write, snapshot)
            except Exception as e:
                import sys
                sys.stderr.write(f"[HabitTracker] Async Save Error: {e}\n")
            finally:
                self._is_saving = False
                if self._needs_another_save:
                    self._save_habits()

        loop.create_task(_save_task())

    def record_search(self, query: str):
        if not query or len(query) < 2:
            return
        query = query.lower().strip()
        self.habits["search_history"][query] = self.habits["search_history"].get(query, 0) + 1
        self._save_habits()

    def record_install(self, package_name: str, source: str):
        # Update install history
        history = self.habits["install_history"]
        if package_name not in history:
            history[package_name] = {"source": source, "count": 0}
        history[package_name]["count"] += 1

        # Update source preference
        pref = self.habits["source_preference"]
        # Normalize source name to match keys
        norm_source = "Native" if source.lower() == "native" or source.lower() == "pacman" else source
        if norm_source in pref:
            pref[norm_source] += 5 # Installation gives more weight than search
        else:
            pref[norm_source] = 5

        self._save_habits()

    def get_source_weight(self, source: str) -> int:
        norm_source = "Native" if source.lower() == "native" or source.lower() == "pacman" else source
        return self.habits["source_preference"].get(norm_source, 0)

    def get_recommendation_tags(self) -> list:
        """Based on search and install history, return potential tags/keywords for recommendations"""
        # Simple implementation: take most frequent search terms and installed package names
        tags = set()

        # Top searches
        sorted_searches = sorted(self.habits["search_history"].items(), key=lambda x: x[1], reverse=True)
        tags.update([item[0] for item in sorted_searches[:5]])

        # Installed packages (could extract keywords from description, but for now just name)
        tags.update(list(self.habits["install_history"].keys())[:5])

        return list(tags)
