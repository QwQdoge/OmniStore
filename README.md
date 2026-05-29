# OmniStore  🚀

## 项目简介
OmniStore 是一个 **跨平台统一软件仓库搜索与管理工具**，支持 **Pacman、AUR、Flatpak、AppImage、Snap** 等多种仓库，并内置 **AI 辅助**（本地 Ollama、OpenAI 兼容）进行搜索解释、推荐、错误诊断。后端使用 Python 实现业务逻辑，**Rust 常驻守护进程**负责后台自动更新检测与通知，前端基于 **Flutter (Material‑3/MD3)**，提供 **玻璃态 UI、动态动画、国际化**（中、日、英）以及 **镜像/自定义仓库编辑** 界面。

---

## 主要特性
- **多仓库统一搜索**：Pacman、AUR、Flatpak、AppImage、Snap。
- **自定义仓库**：在 UI 中直接编辑 `/etc/pacman.d/mirrorlist`、Flatpak remotes、Snap 源等。
- **AI 助手**：支持 Ollama、Gemini、OpenAI 兼容端点（如 DeepSeek、云雾 API），提供搜索解释、错误分析、推荐方案。
- **Rust Daemon**：后台常驻检测更新、自动更新、桌面通知。
- **现代 UI**：Flutter MD3 主题、玻璃化卡片、流畅动画、响应式布局。
- **一次性启动向导**：首次运行弹出 Onboarding，引导语言、镜像、AI 开关等配置。
- **多语言**：简体中文、繁体中文、日文、英文（可通过 `l10n` 扩展）。
- **高度可配置**：`config.yaml` 完整、注释详细，支持在 UI 中实时编辑。

---

## 安装指南

### 1. Python 后端
```bash
# 创建虚拟环境（推荐）
python3 -m venv .venv
source .venv/bin/activate

# 安装依赖
pip install -r python/requirements.txt
```
> 若不使用虚拟环境，请确保已全局安装所需 Python 包。

### 2. Rust 守护进程
```bash
# 进入 daemon 目录并编译（Release 推荐）
cd daemon
cargo build --release
# 编译产物在 target/release/omnistore-daemon
```
> 守护进程会在第一次运行时自动读取 `~/.config/omnistore/config.yaml`。

### 3. Flutter 前端
```bash
# 安装 Flutter（已安装可省略）
# https://flutter.dev/docs/get-started/install

cd FlutterUI
flutter pub get
flutter run   # 调试运行（macOS 桌面）
# 或者编译发布包
flutter build macos
```

### 4. 启动整套系统
```bash
# 1) 启动 Rust 守护进程（后台运行）
./daemon/target/release/omnistore-daemon &

# 2) 启动 Flutter UI（前端）
cd FlutterUI && flutter run
```

---

## 使用说明
- **搜索**：在 UI 顶部搜索框输入关键字，系统会同时在所有已启用仓库中搜索并显示统一结果。
- **自定义仓库**：打开 **设置 ➜ 镜像编辑** 或 **自定义仓库管理**，可添加/删除 Pacman 镜像、Flatpak remote、Snap 源。
- **AI 助手**：点击 **AI 助手** 按钮或在搜索框使用 `!ask <问题>`，系统会调用配置的 AI 接口返回解释或推荐。
- **自动更新**：守护进程每 `daemon.check_interval_hours` 小时检查一次更新，弹出系统通知并在 UI 上显示红点提示。
- **首次启动向导**：首次打开会出现欢迎页，引导完成语言、镜像、AI 开关的快速配置。

---

## 配置文件 (`config.yaml`)
位于 `~/.config/omnistore/config.yaml`，已在项目首次运行时生成。主要字段示例：
```yaml
first_run: true
search:
  sources:
    pacman: true
    aur: true
    flatpak: true
    appimage: true
    snap: true
  max_results: 100
priority:
  pacman: 100
  aur: 80
  flatpak: 60
  appimage: 40
  snap: 30
ui:
  appearance: system   # light / dark / system
  color_seed: "#4E7EEF"
  language: zh-CN
  use_system_title_bar: false
  close_to_tray: true
ai:
  enabled: true
  provider: ollama   # ollama / openai / gemini
  endpoint: http://localhost:11434
  model: qwen2.5:7b
  api_key: ""
  proxy: ""          # 可选网络代理
custom_repos:
  flatpak: []
  pacman: []
  appimage: []
mirrors:
  pacman: "/etc/pacman.d/mirrorlist"
  flatpak_remotes:
    - "https://dl.flathub.org/repo/flathub.flatpakrepo"
daemon:
  enabled: true
  check_interval_hours: 4
  auto_update: false
  notifications: true
```
> 编辑后保存，UI 会实时读取最新配置。

---

## 开发指南
> 💡 详细的项目架构设计、UI 布局结构与核心模块实现原理，请参考 [project_architecture.md](project_architecture.md)。所有代码修改与升级，必须同步更新该架构设计文档。

### 后端（Python）
- 代码位于 `python/`，核心模块：`core/config_loader.py`、`core/ai/assistant.py`、`core/search/`。
- 运行单元测试：`pytest -q`（需先安装 `pytest`）。

### 守护进程（Rust）
- 入口 `daemon/src/main.rs`，配置解析在 `daemon/src/config.rs`。
- 添加新功能后执行 `cargo test`，确保兼容性。

### 前端（Flutter）
- 入口 `FlutterUI/lib/main.dart`，页面位于 `lib/pages/`，自定义 UI 组件在 `lib/widgets/`。
- 运行 `flutter analyze` 检查代码规范。
- 若需要新增语言，编辑 `lib/l10n/app_localizations.dart` 与对应 `.arb` 文件。

---

## 贡献
1. Fork 本仓库。
2. 创建分支并实现功能或修复 bug。
3. 提交 Pull Request 并通过 CI（Python + Rust + Flutter 单元测试）。

---

## 许可证
本项目遵循 **MIT 许可证**。详情见 `LICENSE`。

---

> **感谢使用 OmniStore**，如有任何问题或建议，请在 GitHub Issues 提交反馈。
