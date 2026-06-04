## 2026-06-04 - Startup performance through lazy loading

**Learning:** Eagerly instantiating all manager components (AI, Installers, etc.) and importing their modules at the top level in a CLI-driven backend significantly penalizes every command's startup time. In OmniStore, search responsiveness was bottlenecked by loading components that are only needed for actions.

**Action:** Prefer lazy-loaded properties with local imports for all non-essential backend managers. Ensure search source discovery is configuration-aware to avoid instantiating disabled repositories.
