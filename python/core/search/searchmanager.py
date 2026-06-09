import asyncio
import aiohttp
from typing import List, Dict, Any, Optional
from core.sources.base import UnifiedSource
from .smart_scoring import SmartScoring
from core.habit_tracker import HabitTracker
from core.recommendation_manager import RecommendationManager
import re
import sys
import logging

_NORM_RE = re.compile(r'-(bin|git|appimage|desktop|flatpak|stable|edge|preview|a|cli|dev|electron|browser)$')

class SearchManager:
    def __init__(self, config_manager: Any, session: aiohttp.ClientSession, habit_tracker: HabitTracker = None, recommender: RecommendationManager = None, cache_manager: Any = None):
        self.cm = config_manager
        self.habit_tracker = habit_tracker or HabitTracker()
        self.smart_scoring = SmartScoring(config_manager, self.habit_tracker)
        self.session = session
        self.recommender = recommender or RecommendationManager(session, self.habit_tracker)
        self.cache = cache_manager
        self.sources: Dict[str, UnifiedSource] = {}
        self.plugin_loader = None
        self._setup_sources()
        self._norm_cache = {}

    def _setup_sources(self):
        self.sources = {}
        import sys
        from core.sources import PacmanSource, AurSource, FlatpakSource, AppImageSource, GitHubSource, BituSource
        from core.sources.external import WingetSource, ScoopSource, BrewSource

        is_linux = sys.platform.startswith("linux")
        is_windows = (sys.platform == "win32")
        is_macos = (sys.platform == "darwin")

        # 1. Cloud sources (available on all platforms)
        self.sources["github"] = GitHubSource(self.session, self.cm)
        self.sources["bitu"] = BituSource(self.session, self.cm)

        # 2. Linux specific sources
        if is_linux:
            if self.cm.get("search.sources.pacman", True):
                self.sources["pacman"] = PacmanSource()
            if self.cm.get("search.sources.aur", True):
                self.sources["aur"] = AurSource(self.session)
            if self.cm.get("search.sources.flatpak", True):
                self.sources["flatpak"] = FlatpakSource()
            if self.cm.get("search.sources.appimage", True):
                self.sources["appimage"] = AppImageSource(self.session, self.cm)

        # 3. Windows specific sources
        if is_windows:
            if self.cm.get("search.sources.winget", True):
                winget = WingetSource()
                if winget.enabled: self.sources["winget"] = winget
            if self.cm.get("search.sources.scoop", True):
                scoop = ScoopSource()
                if scoop.enabled: self.sources["scoop"] = scoop

        # 4. macOS / Linux Brew
        if is_macos or is_linux:
            if self.cm.get("search.sources.brew", True):
                brew = BrewSource()
                if brew.enabled: self.sources["brew"] = brew

        # Load external plugins - only if enabled
        if self.cm.get("search.sources.plugins", True):
            from core.sources.loader import PluginLoader
            try:
                self.plugin_loader = PluginLoader(self)
                self.plugin_loader.load_plugins()
            except Exception as e:
                import logging
                logging.getLogger("omnistore").error(f"Failed to load plugins: {e}")

        # Load custom weights from config (using the "priority" key from config.yaml)
        weights = self.cm.get("priority", {})
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

        # Record the search query
        self.habit_tracker.record_search(query)
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
                            return recs
                        except Exception:
                            return []
                    else:
                        if hasattr(source_obj, "get_recommendations"):
                            try:
                                recs = await source_obj.get_recommendations()
                                return recs
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
        # ⚡ Optimization: Pre-fetch installed packages as tasks to be awaited in parallel by individual sources
        installed_flatpak_task = None
        installed_aur_task = None

        # ⚡ Bolt: Use cached installed packages if available to avoid redundant subprocesses (~150-400ms saved)
        cached_apps = self.cache.get_installed_packages() if self.cache else None

        # Simplified approach: always pre-fetch if these sources are potentially active
        async def _get_flatpak():
            if cached_apps:
                return {app['id'] for app in cached_apps if app.get('primary_source') == 'Flatpak' and app.get('id')}
            p = None
            try:
                p = await asyncio.create_subprocess_exec("flatpak", "list", "--installed", "--columns=application",
                                                        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
                stdout, _ = await p.communicate()
                return {line.strip() for line in stdout.decode().strip().splitlines() if line.strip()}
            except:
                return set()
            finally:
                if p and p.returncode is None:
                    try:
                        p.kill()
                        await p.wait()
                    except: pass

        async def _get_aur():
            if cached_apps:
                return {app['name'] for app in cached_apps if app.get('primary_source') == 'AUR'}
            p = None
            try:
                p = await asyncio.create_subprocess_exec("pacman", "-Qmq", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
                stdout, _ = await p.communicate()
                return {line.split()[0] for line in stdout.decode().strip().splitlines() if line.strip()}
            except:
                return set()
            finally:
                if p and p.returncode is None:
                    try:
                        p.kill()
                        await p.wait()
                    except: pass

        # Only create tasks if the respective sources are active
        active_names = {s.name.lower() for s in active_sources}
        if "flatpak" in active_names:
            installed_flatpak_task = asyncio.create_task(_get_flatpak())

        if "aur" in active_names:
            installed_aur_task = asyncio.create_task(_get_aur())

        # Defensive source execution: failures in one source shouldn't crash everything
        async def safe_search(source: UnifiedSource, q: str, **kwargs):
            try:
                return await asyncio.wait_for(source.search(q, **kwargs), timeout=10)
            except asyncio.TimeoutError:
                logging.warning(f"Search timeout (10s) for source: {source.name}")
                return []
            except Exception as e:
                logging.error(f"Search failed for source {source.name}: {e}")
                return []

        tasks = [safe_search(src, query, installed_flatpak_task=installed_flatpak_task, installed_aur_task=installed_aur_task) for src in active_sources]
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
        potential_sources = list(self.sources.keys())
        source_weights = {s: self.habit_tracker.get_source_weight(s) for s in potential_sources}
        query_re = re.compile(rf"\b{re.escape(query_lower)}")

        # AI Ranking (Optional)
        ai_ranked_names = []
        if self.cm.get("ai.enabled", False) and self.cm.get("ai.ranking_enabled", True):
            try:
                # Ask AI to rank the top results
                candidates = [f"{i['name']} ({i['source']})" for i in combined[:10]]
                if candidates:
                    # ⚡ Optimization: Access AIAssistant via the backend's lazy property if available,
                    # or at least avoid redundant imports/instantiations.
                    # For now, we use a local import but in a real-world scenario, we'd pass it in.
                    from core.ai.assistant import AIAssistant
                    ai = AIAssistant(self.cm.data if hasattr(self.cm, "data") else self.cm)
                    prompt = f"Rank these apps for query '{query}': {', '.join(candidates)}"
                    # Simplified AI ranking logic
                    res = await ai.recommend_apps(prompt, combined[:10])
                    # Parse AI response for preferred names
                    ai_ranked_names = [n.strip() for n in res.split("\n") if n.strip()]
            except Exception: pass

        for item in combined:
            # Base smart score
            base_score = self.smart_scoring._calculate_smart_score(
                item, query_lower, priority_map, source_weights, query_re
            )

            # Apply manual source weights
            source_weight = self.sources.get(item.get("source", "").lower()).weight if self.sources.get(item.get("source", "").lower()) else 1.0
            item['_smart_score'] = base_score * source_weight

            # AI boost
            if item['name'] in ai_ranked_names:
                item['_smart_score'] *= 1.5

            # Restoration: Ensure _norm_name is set for merge_duplicates
            item['_norm_name'] = self._normalize_app_name(item.get('name', 'unknown'))

        combined.sort(key=lambda x: x['_smart_score'], reverse=True)
        merged = self.merge_duplicates(combined)

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
        # Tiered enrichment: top 5 with network, rest without network (cache only)
        tasks = []
        for i, item in enumerate(items):
            if item.get("icon") and item.get("description") and len(item.get("description", "")) >= 50:
                continue

            use_network = (i < 5)
            tasks.append(self._enrich_single(item, use_network=use_network))

        if tasks:
            try:
                await asyncio.wait_for(asyncio.gather(*tasks), timeout=3.5)
            except asyncio.TimeoutError:
                logging.warning("Metadata enrichment timed out (3.5s)")
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
            raw_name = item.get('name', 'unknown')
            norm_key = item.get('_norm_name') or self._normalize_app_name(raw_name)
            source = item.get('source', 'Unknown')
            is_installed = item.get('installed', False)

            variant = {
                "source": source,
                "version": item.get('last_version', 'Unknown'),
                "installed": is_installed,
                "description": item.get('description', ''),
                "id": item.get("id"),
                "url": item.get("url")
            }

            if norm_key not in seen:
                entry = item.copy()
                entry['primary_source'] = source
                # ⚡ Ensure deep copy of variants to prevent cross-entry mutation
                entry['variants'] = [variant.copy()]
                entry['_norm_name'] = norm_key
                entry['_source_types'] = {source}
                seen[norm_key] = entry
            else:
                if source not in seen[norm_key]['_source_types']:
                    seen[norm_key]['variants'].append(variant.copy())
                    seen[norm_key]['_source_types'].add(source)
                if is_installed:
                    seen[norm_key]['installed'] = True

                # Priority mapping
                prio = {"Flatpak": 3, "Pacman": 2, "AUR": 1}
                if prio.get(source, 0) > prio.get(seen[norm_key]['primary_source'], 0):
                    seen[norm_key]['name'] = raw_name
                    seen[norm_key]['primary_source'] = source
                    seen[norm_key]['description'] = item.get('description', seen[norm_key]['description'])
                    if item.get("icon"): seen[norm_key]['icon'] = item["icon"]

        for entry in seen.values(): entry.pop('_source_types', None)
        return list(seen.values())
