# OmniStore Project Architecture & Details

This document outlines the layout, backend details, implementation methods, and critical rules for modifying the project.

> [!IMPORTANT]
> **CRITICAL RULE FOR AI DEVELOPERS:**
> When any files or architectures in this project are modified, you **MUST** update this file (`project_architecture.md`) to keep it aligned with the current implementation and UI layout.

---

## 1. UI Layout Structure (Flutter Frontend)

The front-end is built using Flutter with a Material 3 design system. It uses a modern dual-pane layout:

```
+-----------------------------------------------------------------------+
|                               Window Title Bar                        |
+-------------------+---------------------------------------------------+
|  Sidebar          |  Top Bar (Page Title, Search Button, User Avatar) |
|  - Explore (Top)  +---------------------------------------------------+
|                   |  Main Content Container (Glassmorphism & Rounded) |
|                   |  - HomePage / Explore                             |
|                   |  - SearchPage                                     |
|                   |  - SettingsPage                                   |
|                   |  - DownloadPage                                   |
|  - Download (Bot) |                                                   |
+-------------------+---------------------------------------------------+
|                   |  Global Status Bar (Only visible when downloading)|
+-------------------+---------------------------------------------------+
```

### Components:
- **`lib/main.dart` (`MainNavigationEntry`)**:
  - **Sidebar (`_buildSideBar`)**: Contains a top "Explore" (`Icons.apps_rounded`) button and a bottom "Download" button (`_buildDownloadButton`).
  - **Top Bar (`_buildTopBar`)**: Displays the current page title, a search action icon (navigates to `SearchPage` when clicked, visible on non-search pages), and the user settings avatar button (`_buildUserAvatar`). The avatar uses Material Design theme colors (`colorScheme.primaryContainer`).
  - **Global Status Bar**: At the bottom of the screen, displays background task status, current action logs, and download progress.
- **Pages (`lib/pages/`)**:
  - `homepage.dart`: Displays featured banner cards (Hero section), essential packages grid, and horizontal category shelves (Trending, For You).
  - `searchpage.dart`: Allows querying across different sources (Pacman, AUR, Flatpak, AppImage).
  - `settingpage.dart`: Detailed settings editor (sources toggles, source priorities drag-and-drop list using `onReorderItem`, log levels, backups, etc.).
  - `download_page.dart`: Displays detailed process logs and cancellation actions.
  - `welcome_page.dart`: First-run onboarding wizard.
- **Widgets (`lib/widgets/`)**:
  - `window_title_bar.dart`: Custom draggable window headers.
  - `smooth_progress_bar.dart`: Animated progress display for background installations.

---

## 2. Backend Architecture (Python & Rust)

### Python Backend Daemon (`python/`)
The Python backend serves as the CLI logic wrapper executing tasks.
- **Entry point (`python/main.py`)**: Handles CLI arguments parsing and routes them to backend modules. Outputs JSON metadata or streams callback lines in format `[CALLBACK] {"message": "..."}` or `[PROGRESS] 50` back to Flutter.
- **Core modules (`python/core/`)**:
  - `recommendation_manager.py`: Fetches categorized collections (featured, trending, for_you) from Flathub APIs and integrates user habits for personalization. Implements a 1-hour local JSON cache.
  - `search/`: Unified package search logic.
  - `downloader/`: Process execution for installation/uninstallation flags.
  - `ai/`: AI Assistant wrapper. Supports **Ollama, Gemini, and OpenAI-compatible** endpoints (e.g., DeepSeek, Yunwu). Includes proxy support and configurable temperature.
  - `config_loader.py` & `env_manager.py`: Configuration and environment validation.

### Rust Daemon (`daemon/`)
- A lightweight background service checking package updates and dispatching system notifications using desktop notifications.

---

## 3. Integration & Implementation Methodology

1. **Process Bridge**: The Flutter UI triggers CLI backend tasks asynchronously using `Process.start` on the Python virtualenv executable (`python/.venv/bin/python`) targeting `python/main.py`.
2. **Real-time Log Streaming**: Outputs from Python's standard output are parsed line-by-line via `Stream<String>` in Flutter's `BackendService`. Progress percentages marked with `[PROGRESS]` updates the global progress notifier.
3. **Background Tasks**: Long-running background installs are coordinated using the `TaskManager` service to persist state across page navigation.
4. **System Tray Integration**: `UpdateService` initializes a background tray icon using `SystemTray` package with the asset `assets/app_icon.png` to support minimize-to-tray.

---

## 4. Communication Protocol & Standards

### Backend to Frontend Streams:
- **`[PROGRESS] <int>`**: Updates the UI progress bar (0-100). `-1` indicates an indeterminate state (e.g., "Verifying...").
- **`[SPEED] <string>`**: Displays real-time download speed in the status bar.
- **`[CALLBACK] <json>`**: Structured logs for the terminal view.
  - Schema: `{"type": "log", "message": "...", "level": "INFO|ERROR|SUCCESS"}`

---

## 5. 7-Part UX & Stability Standards

To ensure a premium and stable experience, all features must adhere to these 7 pillars:

1.  **Onboarding**: First-run experience must be smooth, using the `WelcomePage` with clear progress indicators and configuration defaults.
2.  **Navigation**: Sidebar must use tooltips for accessibility. Page transitions should be fluid (e.g., `easeInOutExpo`).
3.  **Discovery**: High-quality Hero banners and horizontal shelves for app exploration. Empty states must provide actionable feedback.
4.  **Lifecycle**: Background tasks managed by `TaskManager` with real-time log visibility via the Terminal Dialog.
5.  **Configuration**: Settings must be logically grouped with icons. All text inputs must use persistent controllers in the State to prevent cursor jumps.
6.  **AI Magic**: Intelligent features are highlighted with the `MagicPulseIcon` (Purple gradient). All AI triggers must respect the global `isAIEnabled` state.
7.  **Resilience**: Comprehensive error handling for network requests (45s timeouts) and backend CLI failures. UI must handle missing Material ancestors in sub-pages.
