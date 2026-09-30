import asyncio
import logging
import re
import shutil
import sys
from typing import List, Dict, Any, Optional, Set

import aiohttp
from core.subprocess_utils import safe_subprocess
from core.security_validator import SecurityValidator
from core.sources.base import UnifiedSource
from .scoring import SmartScoring
from core.habit_tracker import HabitTracker
from core.recommendation_manager import RecommendationManager

_NORM_RE = re.compile(
    r'-(bin|git|appimage|desktop|flatpak|stable|edge|preview|a|cli|dev|electron|browser)$'
)

# ⚡ Bolt: Hoist source priorities to a module-level constant to avoid redundant dictionary allocations.
_SOURCE_PRIORITY = {
    "Winget": 6,
    "Flatpak": 6,
    "Pacman": 5,
    "APT": 5,
    "DNF": 5,
    "Zypper": 5,
    "Scoop": 4,
    "Chocolatey": 4,
    "Homebrew": 4,
    "APK": 3,
    "F-Droid": 3,
    "AUR": 2,
    "AppImage": 1,
}

# Maximum size for app name normalization cache to prevent memory leak
_MAX_NORM_CACHE_SIZE = 2000

class SearchManager:
    """
    Murphy-proof Search Manager.
    Orchestrates unified search across package sources with concurrency protection,
    fault isolation, defensive input sanitization, and leak-proof subprocess reaping.
    """

    def __init__(
        self,
        config_manager: Any,
        session: aiohttp.ClientSession,
        habit_tracker: Optional[HabitTracker] = None,
        recommender: Optional[RecommendationManager] = None,
        cache_manager: Any = None,
        ai_assistant: Any = None,
    ):
        self.cm = config_manager
        self.habit_tracker = habit_tracker or HabitTracker()
        self.smart_scoring = SmartScoring(config_manager, self.habit_tracker)
        self.session = session
        self.recommender = recommender or RecommendationManager(
            session, self.habit_tracker
        )
        self.cache = cache_manager
        self.ai_assistant = ai_assistant
        self.sources: Dict[str, UnifiedSource] = {}
        self.plugin_loader = None
        self.plugin_registry = None

        # Murphy-proof: Concurrency protection lock for high-frequency search calls
        self._search_lock = asyncio.Lock()

        # Normalization cache with upper bound cap
        self._norm_cache: Dict[str, str] = {}

        self._setup_sources()

    def _setup_sources(self) -> None:
        """Murphy-proof initialization: Exception isolation during source plugin loading."""
        try:
            from core.sources.plugin_registry import PluginRegistry

            self.plugin_registry = PluginRegistry(self.cm, self.session)
            self.sources = self.plugin_registry.load_sources() or {}
        except Exception as e:
            logging.error(f"Murphy-proof: Critical error loading search plugin registry: {e}")
            self.sources = {}

        # Load custom weights from config with fail-safe fallback
        try:
            weights = (
                self.cm.get("sources.priority", {})
                or self.cm.get("priority", {})
                or {}
            )
            if isinstance(weights, dict):
                for name, weight in weights.items():
                    if name in self.sources and isinstance(weight, (int, float)):
                        self.sources[name].weight = float(weight)
        except Exception as e:
            logging.warning(f"Murphy-proof: Error configuring source priority weights: {e}")

    def _get_active_sources(self) -> List[UnifiedSource]:
        """Murphy-proof: Defensive source filter ensuring source is enabled and non-null."""
        active = []
        if not isinstance(self.sources, dict):
            return active

        for key, source in self.sources.items():
            try:
                if (
                    source
                    and getattr(source, "enabled", False)
                    and self.cm.get(f"search.sources.{key}", True)
                ):
                    active.append(source)
            except Exception as e:
                logging.warning(f"Murphy-proof: Failed checking active status for source '{key}': {e}")
        return active

    async def search_all(self, query: str) -> List[Dict[str, Any]]:
        """
        Execute unified search across all active sources.
        Guarantees:
        - Extreme input sanitization & bounds checking.
        - Concurrency protection via mutex state lock with timeout.
        - Per-source fault isolation & timeout protection.
        - Never raises uncaught exceptions to caller.
        """
        # 1. Extreme Input Validation & Bounds Check
        if query is None or not isinstance(query, str):
            logging.debug("Murphy-proof: Search query is null or non-string.")
            return []

        query = query.strip()
        if len(query) < 2:
            return []

        # Defense against ReDoS / huge memory payloads
        if len(query) > 500:
            logging.warning("Murphy-proof: Search query exceeded max length (500 chars). Truncating.")
            query = query[:500]

        # Security validation check
        try:
            SecurityValidator.validate_search_query(query)
        except ValueError as ve:
            logging.warning(f"Murphy-proof: Search query failed security validation: {ve}")
            return []

        # 2. Concurrency Control (Prevent thrashing / deadlock under rapid clicks)
        try:
            await asyncio.wait_for(self._search_lock.acquire(), timeout=10.0)
        except asyncio.TimeoutError:
            logging.error("Murphy-proof: Search mutex lock timeout (10s). System too busy.")
            return []

        try:
            return await self._execute_search_all(query)
        except Exception as e:
            logging.exception(f"Murphy-proof: Unhandled error in SearchManager.search_all: {e}")
            return []
        finally:
            self._search_lock.release()

    async def _execute_search_all(self, query: str) -> List[Dict[str, Any]]:
        """Internal search workflow isolated inside search_lock."""
        # Category Search Protocol
        if query.startswith("/") or query.startswith("category:"):
            cat_id = (query[1:] if query.startswith("/") else query[9:]).strip().lower()
            mapping = {
                "development": "Development",
                "game": "Game",
                "games": "Game",
                "audio": "AudioVideo",
                "video": "AudioVideo",
                "media": "AudioVideo",
                "audiovideo": "AudioVideo",
                "network": "Network",
                "internet": "Network",
                "system": "System",
                "office": "Office",
                "graphics": "Graphics",
                "utility": "Utility",
                "utilities": "Utility",
            }
            standard_id = mapping.get(cat_id, cat_id.capitalize())
            try:
                results = await self.recommender.get_category_apps(standard_id)
                if isinstance(results, list) and results:
                    return results
            except Exception as e:
                logging.warning(f"Murphy-proof: Failed to get category apps for '{standard_id}': {e}")
            query = f"category:{standard_id}"

        # Source Prefix Filtering (e.g. "source:flatpak" or "source:flatpak term")
        source_filter_obj = None
        if query.lower().startswith("source:"):
            parts = query.split(":", 2)
            source_filter = parts[1].strip().lower()
            remaining = parts[2].strip() if len(parts) > 2 else ""
            if source_filter == "native":
                source_filter = "pacman"
            source_obj = self.sources.get(source_filter)
            if not source_obj:
                return []
            else:
                if remaining == "":
                    if source_filter == "flatpak":
                        try:
                            recs = await self.recommender.get_recommendations()
                            if isinstance(recs, dict):
                                flat: List[Dict[str, Any]] = []
                                for v in recs.values():
                                    if isinstance(v, list):
                                        flat.extend(v)
                                return flat
                            return recs if isinstance(recs, list) else []
                        except Exception as e:
                            logging.warning(f"Murphy-proof: Failed to get recommendations for flatpak: {e}")
                            return []
                    else:
                        if hasattr(source_obj, "get_recommendations"):
                            try:
                                recs = await source_obj.get_recommendations()
                                if isinstance(recs, dict):
                                    flat2: List[Dict[str, Any]] = []
                                    for v in recs.values():
                                        if isinstance(v, list):
                                            flat2.extend(v)
                                    return flat2
                                return recs if isinstance(recs, list) else []
                            except Exception as e:
                                logging.warning(f"Murphy-proof: Failed to get recommendations for source: {e}")
                                return []
                        return []
                query = remaining
                source_filter_obj = source_obj

        # Determine active sources
        if source_filter_obj:
            active_sources = (
                [source_filter_obj]
                if getattr(source_filter_obj, "enabled", False)
                else []
            )
        else:
            active_sources = self._get_active_sources()

        if not active_sources:
            return []

        # Cache pre-filtering for installed app checks
        cached_apps = None
        try:
            cached_apps = self.cache.get_installed_packages() if self.cache else None
        except Exception as e:
            logging.warning(f"Murphy-proof: Failed accessing installed packages cache: {e}")

        cached_sets = {"flatpak": set(), "aur": set(), "winget": set()}
        if isinstance(cached_apps, list):
            for app in cached_apps:
                if not isinstance(app, dict):
                    continue
                src = str(app.get("primary_source", "")).lower()
                if src == "flatpak" and (app_id := app.get("id")):
                    cached_sets["flatpak"].add(str(app_id))
                elif src == "aur" and (app_name := app.get("name")):
                    cached_sets["aur"].add(str(app_name))
                elif src == "winget":
                    val = (
                        str(app.get("id") or app.get("name"))
                        .strip()
                        .lower()
                        .replace(" ", "")
                    )
                    if val:
                        cached_sets["winget"].add(val)

        # Pre-fetch installed packages in parallel for active sources
        installed_flatpak_task = None
        installed_aur_task = None
        installed_winget_task = None

        active_names = {
            getattr(s, "name", "").lower()
            for s in active_sources
            if hasattr(s, "name")
        }

        if "flatpak" in active_names:
            f_cached = cached_sets["flatpak"] if cached_apps is not None else None
            if hasattr(self.cm, "backend") and self.cm.backend:
                installed_flatpak_task = self.cm.backend.create_task(
                    self._get_installed_flatpak(f_cached)
                )
            else:
                installed_flatpak_task = asyncio.create_task(
                    self._get_installed_flatpak(f_cached)
                )

        if "aur" in active_names:
            a_cached = cached_sets["aur"] if cached_apps is not None else None
            if hasattr(self.cm, "backend") and self.cm.backend:
                installed_aur_task = self.cm.backend.create_task(
                    self._get_installed_aur(a_cached)
                )
            else:
                installed_aur_task = asyncio.create_task(
                    self._get_installed_aur(a_cached)
                )

        if "winget" in active_names:
            w_cached = cached_sets["winget"] if cached_apps is not None else None
            if hasattr(self.cm, "backend") and self.cm.backend:
                installed_winget_task = self.cm.backend.create_task(
                    self._get_installed_winget(w_cached)
                )
            else:
                installed_winget_task = asyncio.create_task(
                    self._get_installed_winget(w_cached)
                )

        # Record habit tracking safely
        try:
            self.habit_tracker.record_search(query)
        except Exception as e:
            logging.warning(f"Murphy-proof: Habit tracker error: {e}")

        # Defensive source execution wrapper
        async def safe_search(source: UnifiedSource, q: str, **kwargs) -> List[Dict[str, Any]]:
            source_name = getattr(source, "name", "Unknown")
            try:
                res = await asyncio.wait_for(source.search(q, **kwargs), timeout=10.0)
                return res if isinstance(res, list) else []
            except asyncio.TimeoutError:
                logging.warning(f"Murphy-proof: Search timeout (10s) for source: {source_name}")
                return []
            except Exception as e:
                logging.error(f"Murphy-proof: Search failed for source {source_name}: {e}")
                return []

        tasks = [
            safe_search(
                src,
                query,
                installed_flatpak_task=installed_flatpak_task,
                installed_aur_task=installed_aur_task,
                installed_winget_task=installed_winget_task,
            )
            for src in active_sources
        ]

        try:
            responses = await asyncio.wait_for(
                asyncio.gather(*tasks, return_exceptions=True), timeout=15.0
            )
        except Exception as e:
            logging.error(f"Murphy-proof: Global search gather failed: {e}")
            return []

        combined: List[Dict[str, Any]] = []
        for res in responses:
            if isinstance(res, list):
                combined.extend([item for item in res if isinstance(item, dict)])

        query_lower = query.lower()
        query_norm = self._normalize_app_name(query)
        priority_map = self.cm.get("priority", {}) or {}

        # Pre-calculate source metadata map
        source_metadata = {}
        for s_id, s_obj in self.sources.items():
            s_key = s_id.lower()
            cfg_key = "pacman" if s_key == "native" else s_key
            source_metadata[s_key] = {
                "weight": getattr(s_obj, "weight", 1.0),
                "habit_weight": (
                    self.habit_tracker.get_source_weight(s_id)
                    if self.habit_tracker
                    else 0
                ),
                "prio_score": priority_map.get(cfg_key, 50),
            }

        query_re = re.compile(rf"\b{re.escape(query_lower)}")

        for item in combined:
            raw_name = str(item.get("name") or "unknown")
            item["_norm_name"] = self._normalize_app_name(raw_name)

            name_lower = raw_name.lower()
            description = str(item.get("description") or "")
            truncated_desc = description[:200].lower() if description else ""

            src_key = str(item.get("source") or "").lower()
            meta = source_metadata.get(
                src_key, {"weight": 1.0, "habit_weight": 0, "prio_score": 50}
            )

            try:
                base_score = self.smart_scoring._calculate_smart_score(
                    item,
                    query_lower,
                    priority_map,
                    query_re=query_re,
                    name_lower=name_lower,
                    truncated_desc=truncated_desc,
                    source_habit_weight=meta["habit_weight"],
                    source_prio_score=meta["prio_score"],
                )
            except Exception as e:
                logging.warning(f"Murphy-proof: Scoring error for item '{raw_name}': {e}")
                base_score = 10.0

            item["_smart_score"] = base_score * meta["weight"]

        combined.sort(key=lambda x: x.get("_smart_score", 0), reverse=True)
        merged = self.merge_duplicates(combined)

        # Provider-backed ranking used to happen automatically here whenever AI
        # was enabled. AI calls now live exclusively in Flutter's one-time
        # consent flow, so backend search remains deterministic and offline.

        exact_match_idx = -1
        for idx, item in enumerate(merged):
            if item.get("_norm_name") == query_norm:
                exact_match_idx = idx
                break

        if exact_match_idx != -1:
            exact_match = merged.pop(exact_match_idx)
            exact_match["is_exact_match"] = True
            merged.insert(0, exact_match)

        max_res = self.cm.get("search.max_results", 50)
        if not isinstance(max_res, int) or max_res <= 0:
            max_res = 50

        top_results = merged[:max_res]
        await self._enrich_metadata(top_results[:10])

        for item in top_results:
            item.pop("_smart_score", None)
            item.pop("_norm_name", None)

        return top_results

    async def _get_installed_flatpak(self, cached_set: Optional[Set[str]]) -> Set[str]:
        """Murphy-proof: Environment check, timeout, and subprocess reaping for flatpak."""
        if cached_set is not None:
            return cached_set
        if not sys.platform.startswith("linux") or not shutil.which("flatpak"):
            return set()

        try:
            async with safe_subprocess(
                "flatpak",
                "list",
                "--installed",
                "--columns=application",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
            ) as p:
                stdout, _ = await asyncio.wait_for(p.communicate(), timeout=5.0)
                return {
                    line.strip()
                    for line in stdout.decode(errors="replace").strip().splitlines()
                    if line.strip()
                }
        except Exception as e:
            logging.debug(f"Murphy-proof: Failed to query installed flatpaks: {e}")
            return set()

    async def _get_installed_aur(self, cached_set: Optional[Set[str]]) -> Set[str]:
        """Murphy-proof: Environment check, timeout, and subprocess reaping for pacman/AUR."""
        if cached_set is not None:
            return cached_set
        if not sys.platform.startswith("linux") or not shutil.which("pacman"):
            return set()

        try:
            async with safe_subprocess(
                "pacman",
                "-Qmq",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
            ) as p:
                stdout, _ = await asyncio.wait_for(p.communicate(), timeout=5.0)
                return {
                    line.split()[0]
                    for line in stdout.decode(errors="replace").strip().splitlines()
                    if line.strip()
                }
        except Exception as e:
            logging.debug(f"Murphy-proof: Failed to query installed AUR packages: {e}")
            return set()

    async def _get_installed_winget(self, cached_set: Optional[Set[str]]) -> Set[str]:
        """Murphy-proof: Environment check and fail-safe for winget."""
        if cached_set is not None:
            return cached_set
        if sys.platform != "win32" or not shutil.which("winget"):
            return set()

        source = self.sources.get("winget")
        if source and hasattr(source, "_get_installed_ids"):
            try:
                res = await asyncio.wait_for(source._get_installed_ids(), timeout=5.0)
                return res if isinstance(res, set) else set()
            except Exception as e:
                logging.debug(f"Murphy-proof: Failed to query installed winget apps: {e}")
                return set()
        return set()

    async def _search_single_source(
        self, source: UnifiedSource, query: str
    ) -> List[Dict[str, Any]]:
        """Defensive single source execution with timeout isolation."""
        source_name = getattr(source, "name", "Unknown")
        try:
            res = await asyncio.wait_for(source.search(query), timeout=10.0)
            return res if isinstance(res, list) else []
        except asyncio.TimeoutError:
            logging.warning(f"Murphy-proof: Search timeout (10s) for source: {source_name}")
            return []
        except Exception as e:
            logging.error(f"Murphy-proof: Search failed for source {source_name}: {e}")
            return []

    async def _enrich_metadata(self, items: List[Dict[str, Any]]) -> None:
        """Murphy-proof: Timeout-bounded metadata enrichment."""
        tasks = []
        for i, item in enumerate(items):
            if not isinstance(item, dict):
                continue
            if (
                item.get("icon")
                and item.get("description")
                and len(str(item.get("description", ""))) >= 50
            ):
                continue

            use_network = i < 3
            tasks.append(self._enrich_single(item, use_network=use_network))

        if tasks:
            try:
                await asyncio.wait_for(asyncio.gather(*tasks), timeout=2.5)
            except asyncio.TimeoutError:
                logging.warning("Murphy-proof: Metadata enrichment timed out (2.5s)")
            except Exception as e:
                logging.error(f"Murphy-proof: Metadata enrichment error: {e}")

    async def _enrich_single(self, item: Dict[str, Any], use_network: bool = True) -> None:
        """Fail-safe single item metadata enrichment."""
        try:
            source = str(item.get("source") or "").lower()
            if source == "flatpak" and item.get("id"):
                metadata = await self.recommender.get_details(
                    str(item["id"]), use_network=use_network
                )
            else:
                metadata = await self.recommender.find_metadata(
                    str(item.get("name") or ""), use_network=use_network
                )

            if isinstance(metadata, dict):
                if metadata.get("icon"):
                    item["icon"] = metadata["icon"]
                if metadata.get("description") and len(str(item.get("description", ""))) < 50:
                    item["description"] = metadata["description"]
                if metadata.get("screenshots"):
                    item["screenshots"] = metadata["screenshots"]
        except Exception as e:
            logging.debug(f"Murphy-proof: Enrich single item failed: {e}")

    def _normalize_app_name(self, name: str) -> str:
        """Murphy-proof app name normalization with cache memory cap."""
        if not name or not isinstance(name, str):
            return "unknown"

        if name in self._norm_cache:
            return self._norm_cache[name]

        n = name.lower().strip()

        if "." in n:
            parts = n.split(".")
            if len(parts) > 2:
                n = parts[-1]

        if " " in n:
            n = n.partition(" ")[0]

        n = _NORM_RE.sub("", n)
        n = n.replace("-", "").replace("_", "")

        # Bounds check on norm_cache size
        if len(self._norm_cache) >= _MAX_NORM_CACHE_SIZE:
            self._norm_cache.clear()

        self._norm_cache[name] = n
        return n

    def merge_duplicates(self, items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Murphy-proof duplicate merging with strict type checks."""
        seen: Dict[str, Dict[str, Any]] = {}
        for item in items:
            if not isinstance(item, dict):
                continue

            norm_key = item.get("_norm_name") or self._normalize_app_name(
                str(item.get("name") or "unknown")
            )
            if not norm_key:
                continue

            source = str(item.get("source") or "Unknown")
            is_installed = bool(item.get("installed", False))

            if norm_key not in seen:
                variant = {
                    "source": source,
                    "version": str(item.get("last_version") or "Unknown"),
                    "installed": is_installed,
                    "description": str(item.get("description") or ""),
                    "id": item.get("id"),
                    "url": item.get("url"),
                }
                entry = item.copy()
                entry["primary_source"] = source
                entry["variants"] = [variant]
                entry["_source_types"] = {source}
                seen[norm_key] = entry
            else:
                target = seen[norm_key]
                if source not in target["_source_types"]:
                    target["variants"].append(
                        {
                            "source": source,
                            "version": str(item.get("last_version") or "Unknown"),
                            "installed": is_installed,
                            "description": str(item.get("description") or ""),
                            "id": item.get("id"),
                            "url": item.get("url"),
                        }
                    )
                    target["_source_types"].add(source)
                if is_installed:
                    target["installed"] = True

                if _SOURCE_PRIORITY.get(source, 0) > _SOURCE_PRIORITY.get(
                    str(target.get("primary_source")), 0
                ):
                    target["name"] = item.get("name", "unknown")
                    target["primary_source"] = source
                    target["description"] = item.get("description", target.get("description", ""))
                    target["id"] = item.get("id")
                    target["url"] = item.get("url")
                    if icon := item.get("icon"):
                        target["icon"] = icon

        for entry in seen.values():
            entry.pop("_source_types", None)
        return list(seen.values())
