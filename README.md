# OmniStore 🚀

## Introduction
OmniStore is a **cross-platform unified software store and management tool**. It supports multiple repositories including **Pacman, AUR, Flatpak, AppImage, and Snap**. Built with **AI assistance** (supporting local Ollama, OpenAI-compatible, and Gemini), it provides intelligent search correction, recommendations, update summaries, and error diagnostics.

The backend is implemented in Python for business logic, with a **Rust resident daemon** responsible for background update detection and notifications. The frontend is built with **Flutter (Material-3/MD3)**, featuring a glassmorphism UI, fluid animations, internationalization (English, Chinese, Japanese, Spanish), and built-in mirror/repository editors.

---

## Key Features
- **Unified Multi-Repo Search**: Simultaneous search across Pacman, AUR, Flatpak, AppImage, and Snap.
- **Custom Repository Management**: Edit `/etc/pacman.d/mirrorlist`, Flatpak remotes, and Snap sources directly from the UI.
- **Deep AI Integration**:
  - **Search Assistant**: Automatic spelling correction, keyword associations, and semantic search.
  - **Daily Picks**: AI-curated high-quality apps selected from thousands of packages daily.
  - **Variant Comparison**: Compare different versions (e.g., Flatpak vs. AUR) for sandboxing, stability, and update frequency.
  - **Update Interpretation**: Translates technical changelogs into easy-to-understand feature summaries.
  - **Conflict Warning**: Scans for potential dependency conflicts or functional overlap before installation.
  - **Magic Terminal**: Generates precise terminal commands for power users.
  - **System Health**: AI-driven evaluation of orphaned packages, cache, and system load.
- **Rust Daemon**: Lightweight background service for update checks and desktop notifications.
- **Modern MD3 UI**: Material 3 design, glassmorphism cards, responsive layouts, and smooth navigation.
- **Onboarding Wizard**: First-run experience to guide language, mirror, and AI configuration.
- **Highly Configurable**: All settings are stored in a clear `config.yaml` and can be edited in real-time within the app.

---

## Installation Guide

### 1. Python Backend
```bash
# Create virtual environment (recommended)
python3 -m venv python/.venv
source python/.venv/bin/activate

# Install dependencies
pip install -r python/requirements.txt
```

### 2. Rust Daemon
```bash
# Enter daemon directory and build
cd daemon
cargo build --release
# Binary is located at daemon/target/release/omnistore-daemon
```

### 3. Flutter Frontend
```bash
cd FlutterUI
flutter pub get
flutter run   # Debug run
# Or build release
# flutter build linux / windows / macos
```

### 4. Running the System
1. Start the Rust daemon: `./daemon/target/release/omnistore-daemon &`
2. Start the Flutter UI: `cd FlutterUI && flutter run`

---

## Configuration (`config.yaml`)
Located at `~/.config/omnistore/config.yaml`. Example structure:
```yaml
search:
  sources:
    pacman: true
    aur: true
    flatpak: true
  max_results: 100
ui:
  appearance: system
  color_seed: "#6750A4"
  language: en
ai:
  enabled: true
  provider: ollama
  endpoint: http://localhost:11434
  model: qwen2.5:7b
daemon:
  enabled: true
  check_interval_hours: 4
```

---

## Development

| Document | Contents |
|----------|----------|
| [project_architecture.md](project_architecture.md) | Whole-repo diagram, Python/Rust, protocols |
| [PROJECT_CONTEXT.zh-CN.md](PROJECT_CONTEXT.zh-CN.md) | 中文项目环境说明、模块职责、运行入口、开发注意事项 |
| [FlutterUI/ARCHITECTURE.md](FlutterUI/ARCHITECTURE.md) | Flutter layers, features, navigation indices |
| [FlutterUI/lib/README.md](FlutterUI/lib/README.md) | Quick `lib/` tree index |

**Flutter `lib/` layers:** `app/` → `features/` → `data/` (Python CLI) · `core/` · `services/` · `widgets/`

### Contribution
1. Fork the repository.
2. Create a feature branch.
3. Submit a Pull Request and ensure it passes CI checks (Python + Rust + Flutter).

---

## License
OmniStore is licensed under the **MIT License**. See `LICENSE` for details.

---
> **Thank you for using OmniStore!** Please report any issues or suggestions on GitHub.
