## 2026-06-04 - Startup performance through lazy loading

**Learning:** Eagerly instantiating all manager components (AI, Installers, etc.) and importing their modules at the top level in a CLI-driven backend significantly penalizes every command's startup time. In OmniStore, search responsiveness was bottlenecked by loading components that are only needed for actions.

**Action:** Prefer lazy-loaded properties with local imports for all non-essential backend managers. Ensure search source discovery is configuration-aware to avoid instantiating disabled repositories.

## 2026-06-05 - Subprocess Task Coalescing in Search

**Learning:** Running identical subprocess commands (like `flatpak list` or `pacman -Qmq`) across multiple search sources (e.g., FlatpakSource and AurSource) creates significant I/O overhead. Serializing these before the search tasks increases total latency.

**Action:** Kick off background tasks for common system metadata (like installed packages) in the search manager and pass these tasks (not the awaited results) to individual sources via `**kwargs`. This allows sources to await the results in parallel with their own network/I/O tasks, reducing overall latency.

## 2026-06-06 - Search latency optimization via cache coalescing

**Learning:** Running identical subprocess commands (like `flatpak list` or `pacman -Qmq`) during every search query adds 150-400ms of latency. Even with parallel execution, the overhead of spawning processes on every keystroke (in a CLI-driven backend) is significant.

**Action:** Implement "Cache Coalescing" in the search pipeline. `SearchManager` now attempts to pull the list of installed package IDs/names from the existing `CacheManager` (populated by the background scan) before falling back to subprocesses. This converts an I/O-bound task into a memory/cache lookup in the hot path.
