# OmniStore 项目环境说明（中文）

本文档记录对当前仓库的整体理解，便于后续在本环境中继续开发、调试和交接。

## 项目定位

OmniStore 是一个跨平台统一软件商店与软件管理工具。它把多个软件来源聚合到同一套搜索、安装、卸载、更新和推荐流程中，并通过 Flutter 提供桌面端/移动端风格一致的 Material 3 界面，通过 Python 后端承载包管理、源管理、AI 辅助和系统集成逻辑。

当前仓库重点由以下部分组成：

| 路径 | 技术栈 | 主要职责 |
| --- | --- | --- |
| `FlutterUI/` | Dart / Flutter | 用户界面、导航、设置页、搜索/详情页、任务管理、国际化、本地服务封装 |
| `python/` | Python / asyncio | CLI 入口、包源聚合、安装/卸载/更新、AI 辅助、配置、缓存、后台 daemon server |
| `plugins/` | JSON + Python 插件 | 内置或示例软件源插件元数据，以及可动态注册的 `UnifiedSource` 插件 |
| `scripts/` | Python / PowerShell | 辅助脚本，例如本地化检查和 PR 合并自动化 |
| 根目录配置 | YAML / JSON / Python | 构建脚本、配置 schema、项目文档、PKGBUILD、图标资源 |

> 注意：`README.md` 与 `project_architecture.md` 提到 Rust daemon，但当前工作树中没有 `daemon/` 目录；目前实际可见的是 Python 侧 `--daemon` 模式和 `python/core/daemon_server.py`。

## 运行入口与进程关系

### Flutter 前端

Flutter 应用入口是 `FlutterUI/lib/main.dart`，它只调用 `bootstrapOmniStore()`。实际应用初始化、Provider 注入、主题、导航和服务装配分散在 `FlutterUI/lib/app/`、`FlutterUI/lib/services/`、`FlutterUI/lib/data/` 和各 `features/` 模块中。

前端通过 repository/service 层调用 Python：

1. UI 页面或 controller 发起搜索、安装、设置读取等操作。
2. `FlutterUI/lib/data/repositories/*` 或 `FlutterUI/lib/services/*` 组装参数。
3. `FlutterUI/lib/data/python_bridge.dart` 选择 Python 解释器并构建 CLI 参数。
4. Python 输出 JSON、`[PROGRESS]`、`[SPEED]`、`[CALLBACK]` 等流式标记。
5. Flutter 解析输出并更新页面或任务状态。

### Python 后端

Python 主入口是 `python/main.py`。它通过 `argparse` 暴露统一 CLI，包括：

- 搜索：`-S/--search`
- 安装：`-I/--install`
- 卸载：`-R/--remove`
- 更新：`-U/--update`
- 检查更新：`-C/--check-updates`
- 已安装列表：`-L/--list-installed`
- 软件详情、推荐、清理、导入/导出包列表
- AI 解释、推荐、错误分析、对比、健康检查、命令生成、冲突分析
- 配置读取/写入、环境检查、插件管理、自定义源管理
- `--daemon` 本地后台服务模式

核心后端类是 `python/core/backend.py` 中的 `OmnistoreBackend`。该模块还提供 stdout 劫持、资源协调、命令安全包装和 JSON/流式输出控制，保证 Flutter 可以稳定解析后端结果。

## Python 后端分层

| 模块 | 作用 |
| --- | --- |
| `python/core/backend.py` | 后端门面，统一调度搜索、安装、更新、AI、配置和清理等能力 |
| `python/core/cli_handler.py` | 将 `python/main.py` 的命令行参数分派到后端方法 |
| `python/core/models.py` | 跨模块数据模型，例如软件包、变体、命令响应、更新信息 |
| `python/core/config_loader.py` | 加载、读取和写入配置 |
| `python/core/cache_manager.py` | 缓存管理 |
| `python/core/env_manager.py` | 环境检查与 bootstrap |
| `python/core/search/` | 搜索管理、评分、特定源搜索适配 |
| `python/core/sources/` | `UnifiedSource` 抽象和 Pacman/AUR/Flatpak/AppImage/GitHub/Bitu 等源实现 |
| `python/core/downloader/` | 下载管理和 AppImage 处理 |
| `python/core/ai/assistant.py` | AI provider 适配、摘要、推荐、错误分析等能力 |
| `python/core/daemon_server.py` | Python daemon server 和 watchdog |
| `python/core/security_validator.py` | 参数与字符串安全校验 |
| `python/core/friendly_messages.py` | 面向用户的友好提示文案 |

## 软件源和插件机制

项目有两套相关概念：

1. **内置软件源实现**：位于 `python/core/sources/`，以 `UnifiedSource` 为统一接口，覆盖 Pacman、AUR、Flatpak、AppImage、GitHub、Bitu 等来源。
2. **插件元数据与动态插件**：`plugins/sources/*/plugin.json` 描述可配置的软件源插件；`plugins/demo_plugin.py` 展示 Python 插件形式。`python/core/sources/manager.py` 中的 `PluginLoader` 会扫描根目录 `plugins/` 下的 `.py` 文件，实例化继承 `UnifiedSource` 的类并注册到搜索管理器。

新增软件源时，应优先明确它属于内置源还是插件源：

- 如果需要深度参与搜索、安装、更新、配置和测试，放入 `python/core/sources/` 更合适。
- 如果只是扩展外部来源并希望用户可开关，优先通过 `plugins/sources/<id>/plugin.json` 和动态插件机制表达。

## 配置体系

主要配置模板位于 `python/config.yaml`，根目录的 `config_schema.json` 定义了配置结构约束。配置覆盖：

- 搜索源开关和最大结果数
- 源优先级和展示顺序
- 插件启用状态和插件配置
- UI 外观、语言、托盘行为和标题栏行为
- 日志等级、通知、更新策略
- AI provider、endpoint、model、api key、temperature
- GitHub PAT、自定义源、镜像地址和 daemon 设置

开发时不应在代码中硬编码这些设置；新增配置项时要同步更新模板、schema、读取逻辑和 UI 表单。

## Flutter 前端结构

`FlutterUI/lib/` 采用 feature-first 与分层混合结构：

| 路径 | 说明 |
| --- | --- |
| `app/` | 应用 bootstrap、`MaterialApp`、主导航入口 |
| `features/home/` | 首页、Hero 区、AI 推荐、快速分类、导入包对话框 |
| `features/explore/` | 搜索页、分类页、详情页、GitHub/Flatpak 商店、结果列表和详情组件 |
| `features/apps/` | 已安装应用列表 |
| `features/settings/` | 设置页、AI 设置、源配置、存储清理、通用设置等 |
| `features/task_manager/` | 下载/安装/更新任务页面、任务控制器、终端日志对话框 |
| `features/onboarding/` | 首次运行欢迎页 |
| `data/` | Python bridge 和 repository 层 |
| `services/` | 历史、国际化、更新等应用服务 |
| `models/` | Flutter 侧数据模型 |
| `l10n/` | ARB 文件和生成的本地化 Dart 文件 |

国际化当前包含 English、中文、繁体中文、日本語、西班牙语相关文件。新增 UI 文案时应优先写入 ARB 并重新生成本地化代码，而不是把字符串硬编码在 widget 中。

## 流式协议

Python 到 Flutter 的长任务输出当前混合使用 JSON 和文本标记：

| 标记 | 含义 |
| --- | --- |
| `[PROGRESS] <int>` | 进度百分比，`-1` 表示不确定进度 |
| `[SPEED] <string>` | 下载速度文本 |
| `[CALLBACK] <json>` | 终端日志、状态回调或用户可见消息 |

这套协议对 stdout 纯净度敏感，因此 Python 侧有 `setup_stdout_hijack()` 和 `hijacked_print()` 来避免非 JSON 噪声污染 Flutter 解析。后续如果改动 CLI 输出，需要同时检查 Flutter 解析逻辑。

## 测试与质量检查

可用检查主要分为 Python 和 Flutter：

- Python：`python -m pytest python/tests`
- Flutter：在 `FlutterUI/` 下运行 `flutter test`
- 静态类型：仓库包含 `pyrightconfig.json`，可运行 `pyright`（取决于环境是否安装依赖）
- 本地化辅助：`python/compare_l10n.py`、`scripts/compare_l10n.py`、`scripts/fix_arb_duplicates.py`

由于项目调用系统包管理器、Flatpak、AUR、GitHub 和 AI provider，部分集成行为依赖宿主机环境、网络和系统命令可用性。测试失败时需要区分代码缺陷与环境缺失。

## 开发注意事项

1. **保持 CLI 输出稳定**：Flutter 依赖 Python stdout 协议，任何额外 print 都可能破坏解析。
2. **配置优先**：新增行为优先通过 `python/config.yaml` 和 `config_schema.json` 管理。
3. **软件源变更要补测试**：尤其是搜索结果字段、安装命令和异常处理路径。
4. **Flutter 文案要走 l10n**：避免新增硬编码字符串。
5. **插件加载要防御式处理**：插件来自外部文件，必须保证异常不会拖垮主搜索流程。
6. **跨平台逻辑要显式降级**：项目目标跨平台，但许多后端能力以 Linux/Arch 为主，需要在 Windows/macOS 或缺少命令时给出友好错误。
7. **架构文档要同步**：目录、协议或导航有变化时，同步更新 `README.md`、`project_architecture.md` 或本文档。

## 建议的首次上手顺序

1. 阅读 `README.md` 了解产品目标和启动方式。
2. 阅读 `project_architecture.md` 理解整体结构和待办事项。
3. 查看 `python/main.py` 和 `python/core/cli_handler.py` 理解 CLI 命令入口。
4. 查看 `python/core/backend.py` 理解后端核心调度。
5. 查看 `python/core/sources/base.py` 和 `python/core/sources/manager.py` 理解源接口与插件加载。
6. 查看 `FlutterUI/lib/data/python_bridge.dart` 理解 Flutter 如何调用 Python。
7. 查看 `FlutterUI/lib/app/` 与 `FlutterUI/lib/features/` 理解 UI 组织。
8. 运行 Python 与 Flutter 测试，建立可回归的开发基线。

## 多平台源与插件启用策略

当前插件注册表采用“先发现、后启用”的策略：内置和外部源会显示在 `--list-plugins` 结果中，但 `default_enabled` 默认为 `false`。用户应先查看 `available`、`trusted`、`permissions`、`platforms` 和 `config_schema`，确认可信后再通过 `--set-plugin-enabled plugin.id=true` 显式启用。

AUR/yay 相关能力不会默认启用，因为它依赖用户本机 helper、构建脚本和系统包管理权限；即使在 Linux 上可见，也必须由用户主动审阅后启用。新增跨平台源包括 Debian/Ubuntu APT、Fedora/RHEL DNF、openSUSE Zypper、Alpine APK、Windows Chocolatey，以及 Android/F-Droid（通过 `fdroidcl`）。搜索结果合并会按规范化名称去重，并把不同源保留为 variants，避免同一个应用在多源搜索时重复刷屏。
