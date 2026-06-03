## 2024-03-20 - Documentation and Localization Refinement

**Learning:** Hardcoded strings in navigation and sidebar components are easily overlooked but significantly impact internationalization. Unifying these early under `AppLocalizations` ensures a professional feel across all supported locales.

**Action:** Always check `main.dart` and top-level navigation components for hardcoded labels during UI audits.

**Learning:** `project_architecture.md` can drift quickly from the actual file structure. Maintaining this file is critical for agent onboarding and consistent development.

**Action:** Update `project_architecture.md` and `FlutterUI/ARCHITECTURE.md` whenever features move (e.g. under `lib/features/<name>/presentation/`). Keep `lib/data/` vs `python/` naming distinct in docs.

**Learning:** Empty search states are high-value real estate. Providing category quick-access and trending apps instead of a blank screen improves user engagement and discovery.

**Action:** Implement discovery shelves in `SearchPage` that leverage existing `BrowseController` data (like `recommendations['trending']`).
