## 2024-03-20 - Documentation and Localization Refinement

**Learning:** Hardcoded strings in navigation and sidebar components are easily overlooked but significantly impact internationalization. Unifying these early under `AppLocalizations` ensures a professional feel across all supported locales.

**Action:** Always check `main.dart` and top-level navigation components for hardcoded labels during UI audits.

**Learning:** `project_architecture.md` can drift quickly from the actual file structure. Maintaining this file is critical for agent onboarding and consistent development.

**Action:** Update `project_architecture.md` and `FlutterUI/ARCHITECTURE.md` whenever features move (e.g. under `lib/features/<name>/presentation/`). Keep `lib/data/` vs `python/` naming distinct in docs.

**Learning:** Empty search states are high-value real estate. Providing category quick-access and trending apps instead of a blank screen improves user engagement and discovery.

**Action:** Implement discovery shelves in `SearchPage` that leverage existing `BrowseController` data (like `recommendations['trending']`).

## 2024-03-22 - Extracting Oversized Dialog Widgets

**Learning:** Large monolithic files, especially in presentation layers (like `details_page.dart`), quickly become difficult to navigate and maintain when they contain numerous inline dialog builders.

**Action:** Extract inline dialog definitions (e.g., `showDialog(builder: (ctx) => AlertDialog(...))`) into their own `StatelessWidget` files within a `widgets/` subdirectory. This significantly cleans up the main UI class, makes the dialogs reusable across the app (like `TerminalDialog`), and makes unit testing the dialog components easier.

## 2024-03-22 - Extracting Action Dialog Widgets

**Learning:** Extracted action confirmation and AUR security warning dialogs from `details_page.dart` into a new `action_dialogs.dart` widget to reduce file size and simplify `details_page.dart` UI logic.

**Action:** Continue identifying oversized widgets and inline widget building logic, extracting them into dedicated component files where logical.
