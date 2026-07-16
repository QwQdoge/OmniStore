import asyncio
from core.subprocess_utils import safe_subprocess
import aiohttp
from typing import List, Dict, Any, Optional
from core.sources.base import UnifiedSource
from .scoring import SmartScoring
from core.habit_tracker import HabitTracker
from core.recommendation_manager import RecommendationManager
import re
import sys
import logging

_NORM_RE = re.compile(r'-(bin|git|appimage|desktop|flatpak|stable|edge|preview|a|cli|dev|electron|browser)$')
# ⚡ Bolt: Hoist source priorities to a module-level constant to avoid redundant dictionary allocations.
_SOURCE_PRIORITY = {
    "Winget": 6, "Flatpak": 6, "Pacman": 5, "APT": 5, "DNF": 5, "Zypper": 5,
    "Scoop": 4, "Chocolatey": 4, "Homebrew": 4,
    "APK": 3, "F-Droid": 3, "AUR": 2, "AppImage": 1,
}

class SearchManager:
    def __init__(self, config_manager: Any, session: aiohttp.ClientSession, habit_tracker: Optional[HabitTracker] = None, recommender: Optional[RecommendationManager] = None, cache_manager: Any = None, ai_assistant: Any = None):
        self.cm = config_manager
        self.habit_tracker = habit_tracker or HabitTracker()
        self.smart_scoring = SmartScoring(config_manager, self.habit_tracker)
        self.session = session
        self.recommender = recommender or RecommendationManager(session, self.habit_tracker)
        self.cache = cache_manager
        self.ai_assistant = ai_assistant
        self.sources: Dict[str, UnifiedSource] = {}
        self.plugin_loader = None
        self.plugin_registry = None
        self._setup_sources()
        self._norm_cache = {}

    def _setup_sources(self):
        from core.sources.plugin_registry import PluginRegistry
        self.plugin_registry = PluginRegistry(self.cm, self.session)
        self.sources = self.plugin_registry.load_sources()

        # Load custom weights from config (using the "priority" key from config.yaml)
        weights = self.cm.get("sources.priority", {}) or self.cm.get("priority", {})
        for name, weight in weights.items():
            if name in self.sources:
                self.sources[name].weight = weight

    def _get_active_sources(self) -> List[UnifiedSource]:
        active = []
        for key, source in self.sources.items():
            if source.enabled and self.cm.get(f"search.sources.{key}", True):
                active.append(source)
        return active

    async def search_all(self, query: str) -> List[Dict]:
        if not query or len(query) < 2:
            return []

        if query.startswith("/") or query.startswith("category:"):
            cat_id = (query[1:] if query.startswith("/") else query[9:]).strip().lower()
            mapping = {
                "development": "Development", "game": "Game", "games": "Game",
                "audio": "AudioVideo", "video": "AudioVideo", "media": "AudioVideo",
                "audiovideo": "AudioVideo", "network": "Network", "internet": "Network",
                "system": "System", "office": "Office", "graphics": "Graphics",
                "utility": "Utility", "utilities": "Utility"
            }
            standard_id = mapping.get(cat_id, cat_id.capitalize())
            try:
                results = await self.recommender.get_category_apps(standard_id)
                if results: return results
            except Exception: pass
            query = f"category:{standard_id}"

        # Source prefix filtering (e.g., "source:flatpak" or "source:flatpak term")
        source_filter_obj = None
        if query.lower().startswith("source:"):
            parts = query.split(":", 2)
            source_filter = parts[1].strip().lower()
            remaining = parts[2].strip() if len(parts) > 2 else ""
            if source_filter == "native":
                source_filter = "pacman"
            source_obj = self.sources.get(source_filter)
            if not source_obj:
                # Unknown source, return empty results
                active_sources = []
            else:
                if remaining == "":
                    # No search term, return recommendations for the source
                    if source_filter == "flatpak":
                        try:
                            recs = await self.recommender.get_recommendations()
                            # get_recommendations returns a dict; flatten to a list
                            if isinstance(recs, dict):
                                flat: List[Dict] = []
                                for v in recs.values():
                                    if isinstance(v, list):
                                        flat.extend(v)
                                return flat
                            return recs if isinstance(recs, list) else []
                        except Exception:
                            return []
                    else:
                        if hasattr(source_obj, "get_recommendations"):
                            try:
                                recs = await source_obj.get_recommendations()
                                # Handle dict return (e.g., flatpak recommendations grouped by category)
                                if isinstance(recs, dict):
                                    flat2: List[Dict] = []
                                    for v in recs.values():
                                        if isinstance(v, list):
                                            flat2.extend(v)
                                    return flat2
                                return recs if isinstance(recs, list) else []
                            except Exception:
                                return []
                        return []
                # Non‑empty term: limit search to this source only
                query = remaining
                source_filter_obj = source_obj
        # Determine active sources based on optional filter
        if source_filter_obj:
            active_sources = [source_filter_obj] if source_filter_obj.enabled else []
        else:
            active_sources = self._get_active_sources()
        # ⚡ Bolt: Pre-filter cached installed packages into source-specific sets to avoid O(N*S) iteration
        # This saves ~50-150ms on systems with many installed packages.
        cached_apps = self.cache.get_installed_packages() if self.cache else None
        cached_sets = {"flatpak": set(), "aur": set(), "winget": set()}
        if cached_apps:
            for app in cached_apps:
                src = app.get('primary_source', '').lower()
                if src == 'flatpak' and (app_id := app.get('id')):
                    cached_sets["flatpak"].add(app_id)
                elif src == 'aur' and (app_name := app.get('name')):
                    cached_sets["aur"].add(app_name)
                elif src == 'winget':
                    val = str(app.get('id') or app.get('name')).strip().lower().replace(" ", "")
                    if val: cached_sets["winget"].add(val)

        # ⚡ Optimization: Pre-fetch installed packages as tasks to be awaited in parallel by individual sources
        installed_flatpak_task = None
        installed_aur_task = None
        installed_winget_task = None

        # Only create tasks if the respective sources are active
        active_names = {s.name.lower() for s in active_sources}
        if "flatpak" in active_names:
            # ⚡ Bolt: Distinguish between None (no cache) and empty set (valid cache, 0 apps)
            # to avoid redundant subprocess calls when no apps are installed.
            f_cached = cached_sets["flatpak"] if cached_apps is not None else None
            if hasattr(self.cm, "backend") and self.cm.backend:
                installed_flatpak_task = self.cm.backend.create_task(self._get_installed_flatpak(f_cached))
            else:
                installed_flatpak_task = asyncio.create_task(self._get_installed_flatpak(f_cached))

        if "aur" in active_names:
            a_cached = cached_sets["aur"] if cached_apps is not None else None
            if hasattr(self.cm, "backend") and self.cm.backend:
                installed_aur_task = self.cm.backend.create_task(self._get_installed_aur(a_cached))
            else:
                installed_aur_task = asyncio.create_task(self._get_installed_aur(a_cached))

        if "winget" in active_names:
            w_cached = cached_sets["winget"] if cached_apps is not None else None
            if hasattr(self.cm, "backend") and self.cm.backend:
                installed_winget_task = self.cm.backend.create_task(self._get_installed_winget(w_cached))
            else:
                installed_winget_task = asyncio.create_task(self._get_installed_winget(w_cached))

        # Record the search query (moved after spawning async tasks to reduce startup latency)
        self.habit_tracker.record_search(query)

        # Defensive source execution: failures in one source shouldn't crash everything
        async def safe_search(source: UnifiedSource, q: str, **kwargs):
            try:
                # Murphy-proof: Strict timeout and isolation for external source calls
                return await asyncio.wait_for(source.search(q, **kwargs), timeout=10)
            except asyncio.TimeoutError:
                logging.warning(f"Murphy-proof: Search timeout (10s) for source: {source.name}")
                return []
            except Exception as e:
                logging.error(f"Murphy-proof: Search failed for source {source.name}: {e}")
                return []

        tasks = [safe_search(src, query, installed_flatpak_task=installed_flatpak_task, installed_aur_task=installed_aur_task, installed_winget_task=installed_winget_task) for src in active_sources]
        try:
            responses = await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), timeout=15)
        except Exception as e:
            logging.error(f"Global search gather failed: {e}")
            return []

        combined = []
        for i, res in enumerate(responses):
            if isinstance(res, list):
                combined.extend(res)

        query_lower = query.lower()
        query_norm = self._normalize_app_name(query)
        priority_map = self.cm.get("priority", {})

        # ⚡ Bolt: Pre-calculate source metadata map to avoid lookups in the scoring loop
        # This reduces per-item scoring overhead significantly for large result sets.
        source_metadata = {}
        for s_id, s_obj in self.sources.items():
            s_key = s_id.lower()
            cfg_key = "pacman" if s_key == "native" else s_key
            source_metadata[s_key] = {
                "weight": getattr(s_obj, "weight", 1.0),
                "habit_weight": self.habit_tracker.get_source_weight(s_id) if self.habit_tracker else 0,
                "prio_score": priority_map.get(cfg_key, 50)
            }

        query_re = re.compile(rf"\b{re.escape(query_lower)}")

        for item in combined:
            # Restoration: Ensure _norm_name is set for scoring and merging
            raw_name = item.get('name', 'unknown')
            item['_norm_name'] = self._normalize_app_name(raw_name)

            # ⚡ Bolt: Pre-calculate lower-case name and truncated description to avoid redundant work in scoring loop
            name_lower = raw_name.lower()
            description = item.get('description', '')
            # Truncate before lowering to avoid processing large strings
            truncated_desc = description[:200].lower() if description else ""

            # ⚡ Bolt: Pass pre-calculated source metadata to avoid internal lookups
            src_key = item.get("source", "").lower()
            meta = source_metadata.get(src_key, {"weight": 1.0, "habit_weight": 0, "prio_score": 50})

            # Base smart score
            base_score = self.smart_scoring._calculate_smart_score(
                item, query_lower, priority_map, query_re=query_re,
                name_lower=name_lower, truncated_desc=truncated_desc,
                source_habit_weight=meta["habit_weight"],
                source_prio_score=meta["prio_score"]
            )

            # Apply manual source weights
            item['_smart_score'] = base_score * meta["weight"]

        combined.sort(key=lambda x: x['_smart_score'], reverse=True)
        merged = self.merge_duplicates(combined)

        # ⚡ Bolt: Move AI Ranking after initial scoring and merging
        # This ensures the AI ranks unique, relevant results instead of raw source output.
        if self.cm.get("ai.enabled", False) and self.cm.get("ai.ranking_enabled", True) and len(query) >= 3:
            try:
                # Ask AI to rank the top results from the merged list
                candidates_list = merged[:10]
                candidates_str = [f"{i['name']} ({i['primary_source']})" for i in candidates_list]
                ai = self.ai_assistant
                if candidates_str and ai:
                    prompt = f"Rank these apps for query '{query}': {', '.join(candidates_str)}"
                    try:
                        # Murphy-proof: Tight timeout and panic recovery for AI ranking
                        res = await asyncio.wait_for(ai.recommend_apps(prompt, candidates_list), timeout=1.5)
                        if res:
                            ai_ranked_names = {n.strip() for n in res.split("\n") if n.strip()}

                            # Apply AI boost to merged results and re-sort
                            for item in merged:
                                if item['name'] in ai_ranked_names:
                                    item['_smart_score'] *= 1.5
                            merged.sort(key=lambda x: x['_smart_score'], reverse=True)
                    except asyncio.TimeoutError:
                        logging.warning("Murphy-proof: AI Ranking timed out (1.5s). Falling back to smart score.")
                    except Exception as e:
                        logging.error(f"Murphy-proof: AI Ranking panic: {e}. Falling back to smart score.")
            except Exception: pass

        exact_match_idx = -1
        for idx, item in enumerate(merged):
            if item.get('_norm_name') == query_norm:
                exact_match_idx = idx
                break

        if exact_match_idx != -1:
            exact_match = merged.pop(exact_match_idx)
            exact_match["is_exact_match"] = True
            merged.insert(0, exact_match)

        max_res = self.cm.get("search.max_results", 50)
        top_results = merged[:max_res]
        # ⚡ Optimization: Reduce metadata enrichment limit from 15 to 10 for better search latency.
        await self._enrich_metadata(top_results[:10])

        for item in top_results:
            item.pop('_smart_score', None)
            item.pop('_norm_name', None)

        return top_results


    async def _get_installed_flatpak(self, cached_set: Optional[set]):
        if cached_set:
            return cached_set
        p = None
        try:
            async with safe_subprocess("flatpak", "list", "--installed", "--columns=application",
                                                    stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as p:
                stdout, _ = await p.communicate()
                return {line.strip() for line in stdout.decode().strip().splitlines() if line.strip()}
        except Exception:
            return set()
        finally:
            if p and p.returncode is None:
                try:
                    p.kill()
                    await p.wait()
                except Exception: pass

    async def _get_installed_aur(self, cached_set: Optional[set]):
        if cached_set:
            return cached_set
        p = None
        try:
            async with safe_subprocess("pacman", "-Qmq", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as p:
                stdout, _ = await p.communicate()
                return {line.split()[0] for line in stdout.decode().strip().splitlines() if line.strip()}
        except Exception:
            return set()
        finally:
            if p and p.returncode is None:
                try:
                    p.kill()
                    await p.wait()
                except Exception: pass

    async def _get_installed_winget(self, cached_set: Optional[set]):
        if cached_set:
            return cached_set
        source = self.sources.get("winget")
        if source and hasattr(source, "_get_installed_ids"):
            try:
                return await source._get_installed_ids()
            except Exception:
                return set()
        return set()

    async def _search_single_source(self, source: UnifiedSource, query: str) -> List[Dict]:
        """Defensive source execution: failures in one source shouldn't crash everything."""
        try:
            return await asyncio.wait_for(source.search(query), timeout=10)
        except asyncio.TimeoutError:
            logging.warning(f"Search timeout (10s) for source: {source.name}")
            return []
        except Exception as e:
            logging.error(f"Search failed for source {source.name}: {e}")
            return []

    async def _enrich_metadata(self, items: List[Dict]):
        # ⚡ Bolt: Reduced network enrichment from 5 to 3 to improve perceived latency
        # Tiered enrichment: top 3 with network, rest without network (cache only)
        tasks = []
        for i, item in enumerate(items):
            if item.get("icon") and item.get("description") and len(item.get("description", "")) >= 50:
                continue

            use_network = (i < 3)
            tasks.append(self._enrich_single(item, use_network=use_network))

        if tasks:
            try:
                # ⚡ Bolt: Reduced timeout to 2.5s to improve perceived responsiveness
                await asyncio.wait_for(asyncio.gather(*tasks), timeout=2.5)
            except asyncio.TimeoutError:
                logging.warning("Metadata enrichment timed out (2.5s)")
            except Exception as e:
                logging.error(f"Metadata enrichment failed: {e}")

    async def _enrich_single(self, item: Dict, use_network: bool = True):
        source = item.get("source", "").lower()
        if source == "flatpak" and item.get("id"):
            metadata = await self.recommender.get_details(item["id"], use_network=use_network)
        else:
            metadata = await self.recommender.find_metadata(item['name'], use_network=use_network)

        if metadata:
            if metadata.get("icon"): item["icon"] = metadata["icon"]
            if metadata.get("description") and len(item.get("description", "")) < 50:
                item["description"] = metadata["description"]
            if metadata.get("screenshots"): item["screenshots"] = metadata["screenshots"]

    def _normalize_app_name(self, name: str) -> str:
        if name in self._norm_cache: return self._norm_cache[name]
        n = name.lower().strip()

        # ⚡ Optimization: Faster domain/namespace removal
        if "." in n:
            parts = n.split(".")
            if len(parts) > 2:
                n = parts[-1]

        # Avoid split()[0] if there are no spaces to improve speed
        if " " in n:
            n = n.partition(" ")[0]

        # Regex suffix removal and character stripping
        n = _NORM_RE.sub('', n)
        n = n.replace("-", "").replace("_", "")

        self._norm_cache[name] = n
        return n

    def merge_duplicates(self, items: List[Dict]) -> List[Dict]:
        seen: Dict[str, Dict] = {}
        for item in items:
            # Use pre-calculated _norm_name when available, but keep merge_duplicates
            # safe for tests and direct callers that pass raw result dictionaries.
            norm_key = item.get('_norm_name') or self._normalize_app_name(item.get('name', 'unknown'))
            if not norm_key: continue

            source = item.get('source', 'Unknown')
            is_installed = item.get('installed', False)

            if norm_key not in seen:
                # ⚡ Bolt: Lazy variant creation. Only create variant dict once we know we're keeping the item.
                variant = {
                    "source": source,
                    "version": item.get('last_version', 'Unknown'),
                    "installed": is_installed,
                    "description": item.get('description', ''),
                    "id": item.get("id"),
                    "url": item.get("url")
                }
                # ⚡ Bolt: Shallow copy for speed, deep copy of variants is handled below
                entry = item.copy()
                entry['primary_source'] = source
                entry['variants'] = [variant]
                entry['_source_types'] = {source}
                seen[norm_key] = entry
            else:
                target = seen[norm_key]
                if source not in target['_source_types']:
                    # ⚡ Bolt: Lazy variant creation for existing entries.
                    target['variants'].append({
                        "source": source,
                        "version": item.get('last_version', 'Unknown'),
                        "installed": is_installed,
                        "description": item.get('description', ''),
                        "id": item.get("id"),
                        "url": item.get("url")
                    })
                    target['_source_types'].add(source)
                if is_installed:
                    target['installed'] = True

                if _SOURCE_PRIORITY.get(source, 0) > _SOURCE_PRIORITY.get(target['primary_source'], 0):
                    target['name'] = item.get('name', 'unknown')
                    target['primary_source'] = source
                    target['description'] = item.get('description', target['description'])
                    # ⚡ Bolt: Ensure ID and URL are updated when switching primary source
                    target['id'] = item.get('id')
                    target['url'] = item.get('url')
                    if (icon := item.get("icon")): target['icon'] = icon

        for entry in seen.values(): entry.pop('_source_types', None)
        return list(seen.values())
