// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get searchHint => '搜索应用、游戏、工具...';

  @override
  String get featured => '精选';

  @override
  String get forYou => '为你推荐';

  @override
  String get essentialTools => '必备工具';

  @override
  String get hotApps => '热门应用';

  @override
  String get explore => '探索';

  @override
  String get search => '搜索';

  @override
  String get settings => '设置';

  @override
  String get downloads => '下载';

  @override
  String get help => '帮助';

  @override
  String get userAccount => '用户账户';

  @override
  String get install => '安装';

  @override
  String get open => '打开';

  @override
  String get uninstall => '卸载';

  @override
  String get launch => '启动';

  @override
  String get about => '关于';

  @override
  String get details => '详情';

  @override
  String get source => '来源';

  @override
  String get variant => '可用版本';

  @override
  String get version => '版本';

  @override
  String get ready => '已安装';

  @override
  String resultsFound(int count) {
    return '找到 $count 个结果';
  }

  @override
  String get noResults => '暂无搜索结果';

  @override
  String get searching => '正在搜索...';

  @override
  String get activity => '任务记录';

  @override
  String get category => '分类';

  @override
  String get packageManager => '包管理器';

  @override
  String get pacmanOfficial => 'Pacman（官方库）';

  @override
  String get aurUser => 'AUR（用户库）';

  @override
  String get flatpak => 'Flatpak';

  @override
  String get appImage => 'AppImage';

  @override
  String get sourcePriority => '应用源优先级（拖动排序）';

  @override
  String get maxResults => '最大显示结果数';

  @override
  String get appearance => '界面外观';

  @override
  String get themeColor => '主题色';

  @override
  String get followSystem => '跟随系统';

  @override
  String get lightMode => '浅色模式';

  @override
  String get darkMode => '深色模式';

  @override
  String get loggingLevel => '日志详细程度';

  @override
  String get saveAndApply => '保存并应用';

  @override
  String get configSaved => '配置已保存，部分更改将在重启后生效';

  @override
  String get configSaveFailed => '保存配置失败';

  @override
  String get confirmUninstall => '确认卸载';

  @override
  String get confirmInstall => '确认安装';

  @override
  String confirmActionMsg(String name) {
    return '确定要对 $name 执行此操作吗？';
  }

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get terminalOutput => '终端输出';

  @override
  String get waitingForOutput => '等待终端输出...';

  @override
  String get screenshots => '应用截图';

  @override
  String get developer => '开发者';

  @override
  String get license => '许可';

  @override
  String get success => '成功';

  @override
  String get failed => '失败';

  @override
  String get taskCancelled => '任务已取消';

  @override
  String get catDevelopment => '开发工具';

  @override
  String get catMedia => '影音娱乐';

  @override
  String get catInternet => '互联网';

  @override
  String get catSystem => '系统工具';

  @override
  String get catOffice => '办公';

  @override
  String get catGames => '游戏';

  @override
  String get catGraphics => '图形设计';

  @override
  String get catUtility => '实用工具';

  @override
  String get systemAndWindow => '系统与窗口';

  @override
  String get visitWebsite => '访问官网';

  @override
  String get updates => '更新';

  @override
  String get upToDate => '应用程序已是最新版本';

  @override
  String get checkUpdates => '检查更新';

  @override
  String foundUpdates(int count) {
    return '发现 $count 个可用更新';
  }

  @override
  String get updateAll => '全部更新';

  @override
  String get notifications => '通知设置';

  @override
  String get enableNotifications => '启用通知';

  @override
  String get progressNotifications => '进度通知';

  @override
  String get completionNotifications => '完成通知';

  @override
  String get closeToTray => '关闭时隐藏到系统托盘';

  @override
  String get useSystemTitleBar => '使用系统标题栏';

  @override
  String get showWindow => '显示窗口';

  @override
  String get exit => '退出';

  @override
  String trayTooltipUpdates(int count) {
    return 'OmniStore：共有 $count 项可更新';
  }

  @override
  String get trayTooltipUpToDate => 'OmniStore：应用程序已是最新版本';

  @override
  String get updateReminders => '更新提醒';

  @override
  String get maintenance => '维护';

  @override
  String get updateAllPackages => '更新所有应用';

  @override
  String get includeAurUpdates => '全部更新时包含 AUR';

  @override
  String get resetOnboarding => '重置新手引导';

  @override
  String get resetOnboardingConfirm => '确定要重置新手引导吗？下次启动时将重新显示欢迎页面。';

  @override
  String get checkInterval => '自动检查更新间隔（小时）';

  @override
  String get remindMeOfUpdates => '提醒我有可用更新';

  @override
  String installingApp(String name) {
    return '正在安装 $name';
  }

  @override
  String uninstallingApp(String name) {
    return '正在卸载 $name';
  }

  @override
  String get installSuccessTitle => '安装成功';

  @override
  String get uninstallSuccessTitle => '卸载成功';

  @override
  String get installFailedTitle => '安装失败';

  @override
  String get uninstallFailedTitle => '卸载失败';

  @override
  String get taskCompleted => '任务已完成';

  @override
  String get searchInstalledHint => '搜索已安装的应用...';

  @override
  String get refresh => '刷新';

  @override
  String get noActiveTasks => '暂无活动中的任务';

  @override
  String get currentTask => '当前任务';

  @override
  String get viewLogs => '查看日志';

  @override
  String get allUpdated => '应用程序已是最新版本';

  @override
  String get update => '更新';

  @override
  String get enableSystemTray => '启用系统托盘';

  @override
  String get systemCleaning => '系统清理';

  @override
  String get systemCleaningDesc => '清理孤儿软件包与 pacman 缓存';

  @override
  String get systemCleaningSubtitle => '清理孤儿软件包与 pacman 缓存';

  @override
  String get systemCleaningStarted => '系统清理任务已启动';

  @override
  String get backupAndExport => '备份与导出';

  @override
  String get backupAndExportSubtitle => '导出当前已安装应用列表或从备份导入';

  @override
  String get export => '导出';

  @override
  String get import => '导入';

  @override
  String get selectExportLocation => '选择导出位置';

  @override
  String exportSuccess(int count) {
    return '导出成功：$count 个软件包';
  }

  @override
  String exportFailed(String message) {
    return '导出失败：$message';
  }

  @override
  String get importBackup => '导入备份';

  @override
  String importBackupConfirm(int count) {
    return '已从备份中读取 $count 个软件包。是否开始批量恢复？';
  }

  @override
  String get startRecovery => '开始还原';

  @override
  String get mirrorListSaved => '镜像列表已保存';

  @override
  String get addMirror => '添加镜像';

  @override
  String get serverUrl => '服务器 URL';

  @override
  String get pacmanMirrorManagement => 'Pacman 镜像管理';

  @override
  String get save => '保存';

  @override
  String get add => '添加';

  @override
  String get general => '常规';

  @override
  String get advanced => '高级';

  @override
  String get repositories => '软件源';

  @override
  String get aiSettings => 'AI 助手设置';

  @override
  String get aiEnabled => '启用 AI 助手';

  @override
  String get aiEnabledDesc => '启用 AI 驱动的搜索、应用解析及错误诊断';

  @override
  String get aiProvider => 'AI 服务商';

  @override
  String get aiEndpoint => 'API 接口地址';

  @override
  String get aiModel => '模型名称';

  @override
  String get aiApiKey => 'API 密钥';

  @override
  String get aiProxy => '网络代理（可选）';

  @override
  String get aiTemperature => '温度（创意度）';

  @override
  String get aiMaxTokens => '最大响应长度';

  @override
  String get aiTestButton => '测试 AI 连接';

  @override
  String get aiTestSuccess => 'AI 连接成功！';

  @override
  String aiTestFailed(String error) {
    return 'AI 连接失败：$error';
  }

  @override
  String get aiPromptExplain => '使用 AI 解析';

  @override
  String get aiPromptRecommend => '咨询 AI 建议';

  @override
  String get aiPromptError => 'AI 分析错误';

  @override
  String get aiPickDay => 'AI 今日精选';

  @override
  String get aiPickDaySubtitle => '由 OmniStore AI 提供支持';

  @override
  String get aiCompareTitle => 'AI 版本对比';

  @override
  String get aiHealthTitle => 'AI 系统健康诊断';

  @override
  String get aiHealthSubtitle => '为你的 Arch Linux 进行智能诊断';

  @override
  String get aiCorrection => '您是指：';

  @override
  String get aiThinking => 'AI 正在思考...';

  @override
  String get magicSearch => '智能搜索';

  @override
  String get aiChangelogTitle => 'AI 更新总结';

  @override
  String get aiCliTitle => 'AI 命令生成器';

  @override
  String get aiConflictTitle => 'AI 冲突检测';

  @override
  String get aiCopyCommand => '复制命令';

  @override
  String get aiCommandCopied => '命令已复制到剪贴板';

  @override
  String get aiRefineSearch => '使用 AI 优化搜索';

  @override
  String get aiExplainUpdate => '解析此更新';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowRestore => '还原';

  @override
  String get windowClose => '关闭';

  @override
  String get omnistore => 'OmniStore';

  @override
  String get installedApps => '已安装应用';

  @override
  String get githubStore => 'GitHub 商店';

  @override
  String get flatpakStore => 'Flatpak 商店';

  @override
  String get locateInstallation => '定位安装位置';

  @override
  String get delete => '删除';

  @override
  String get welcomeTitle => '欢迎来到 OmniStore';

  @override
  String get welcomeSubtitle => '为您提供简单、优雅的 Arch Linux 应用管理体验';

  @override
  String get getStarted => '开始使用';

  @override
  String get skip => '跳过';

  @override
  String get envCheckTitle => '环境检查';

  @override
  String get envCheckSubtitle => '我们需要确保您的系统已准备就绪';

  @override
  String get envFatalDesc => '您的系统似乎不是基于 Arch 的，这会导致大部分功能不可用。';

  @override
  String get envWarningDesc => '缺少一些必要的组件，我们可以为您自动配置。';

  @override
  String get envOkDesc => '一切就绪！系统环境已完美配置。';

  @override
  String get fixProblems => '一键修复/配置';

  @override
  String get continueAnyway => '仍然继续';

  @override
  String get sourceConfigTitle => '应用源配置';

  @override
  String get sourceConfigSubtitle => '选择您想要启用的应用来源';

  @override
  String get enableAur => '启用 AUR（Arch User Repository）';

  @override
  String get yayDesc => '启用 AUR 需要安装 yay 助手。';

  @override
  String get aurWarning => '安全警告：AUR 包由用户上传，请确保您信任包的来源。';

  @override
  String get bootstrapNote => '提示：配置过程可能需要多次输入管理员密码。';

  @override
  String get feedbackDesc => '如果您遇到问题，请通过 GitHub 反馈给我们。';

  @override
  String get aiAssistant => 'AI 助手';

  @override
  String get aiAssistantDesc => '启用 AI 驱动的搜索、应用解析及错误诊断';

  @override
  String get aiProviderDesc => '选择您的 AI 模型来源（本地或云端）';

  @override
  String get aiEndpointHelper => 'Ollama 默认为 http://localhost:11434';

  @override
  String get aiApiKeyHelper => '如果是 Ollama 则留空，OpenAI 请填入 sk-xxx';

  @override
  String get howToGetApiKey => '如何获取 API 密钥？';

  @override
  String get howToGetApiKeyDesc =>
      '1. Ollama（本地）：下载并运行 Ollama，无需密钥。2. 云端（OpenAI）：前往服务商官网创建 API Key，然后填入此处。';

  @override
  String get gotIt => '知道了';

  @override
  String get aiOllamaNote =>
      '提示：如果您使用 Ollama，请确保它已在后台运行并开启了 OLLAMA_ORIGINS=\"*\" 环境变量。';

  @override
  String get enterStore => '进入商店';

  @override
  String get nextStep => '下一步';

  @override
  String get resetCache => '重置缓存与历史记录';

  @override
  String get resetCacheDesc => '清空搜索历史与本地推荐缓存';

  @override
  String get resetCacheConfirm => '这将清空您的搜索历史和推荐缓存。是否继续？';

  @override
  String get resetting => '正在重置...';

  @override
  String get resetSuccess => '缓存与历史记录已成功清空';

  @override
  String resetFailed(String error) {
    return '重置失败：$error';
  }

  @override
  String get ollamaLocal => 'Ollama（本地）';

  @override
  String get openaiCompatible => 'OpenAI 兼容';

  @override
  String get googleGemini => 'Google Gemini';

  @override
  String get importPackages => '导入软件包';

  @override
  String importPackagesConfirm(int count) {
    return '已从文件中读取 $count 个软件包。是否开始批量下载？';
  }

  @override
  String get allDownloads => '全部下载';

  @override
  String get importList => '导入列表';

  @override
  String get loadError => '无法加载推荐内容，请检查后端状态';

  @override
  String get community => '社区';

  @override
  String get official => '官方';

  @override
  String get verified => '官方认证';

  @override
  String installingPkg(String name) {
    return '正在安装 $name...';
  }

  @override
  String get switchSource => '切换';

  @override
  String get flatpakBetterDesc => '发现此应用有 Flatpak 源，通常更稳定。';

  @override
  String get aiAnalysisPrompt => '发现错误日志，需要 AI 分析吗？';

  @override
  String get analyzeNow => '立即分析';

  @override
  String get cleanOrphans => '同时清理无用依赖（孤儿软件包）';

  @override
  String get securityWarning => '安全风险提示';

  @override
  String get aurSecurityDesc =>
      'AUR（Arch User Repository） 是由社区维护的软件源。由于其软件包由用户贡献，可能存在安全风险。在安装之前，建议仔细检查 PKGBUILD。';

  @override
  String get continueInstall => '继续安装';

  @override
  String get installInfo => '安装信息';

  @override
  String get downloadSize => '下载大小';

  @override
  String get installedSize => '安装后大小';

  @override
  String dependenciesCount(int count) {
    return '依赖软件包（$count）';
  }

  @override
  String get runningInBackground => 'OmniStore 正在后台运行，可通过托盘图标打开';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get listView => '列表视图';

  @override
  String get gridView => '网格视图';

  @override
  String get categories => '分类';

  @override
  String get clearHistory => '清空历史记录';

  @override
  String get confirmClearHistory => '确定要删除所有搜索历史吗？';

  @override
  String get viewMore => '查看更多';

  @override
  String get logDebug => '调试（DEBUG）';

  @override
  String get logInfo => '信息（INFO）';

  @override
  String get logWarning => '警告（WARNING）';

  @override
  String get logError => '错误（ERROR）';

  @override
  String get notificationTitle => '发现可用更新';

  @override
  String notificationBody(int count) {
    return '你的系统中有 $count 个应用可以更新';
  }

  @override
  String get preparingUpdate => '正在准备更新...';

  @override
  String get processing => '正在处理';

  @override
  String get clear => '清除';

  @override
  String get retry => '重试';

  @override
  String get aiResponseFailed => 'AI 响应失败。';

  @override
  String get aiAnalysisFailed => 'AI 分析失败。';

  @override
  String cannotConnectToBackend(String error) {
    return '无法连接到后端服务：$error';
  }

  @override
  String get taskInitializing => '正在初始化任务...';

  @override
  String get taskStarting => '正在启动...';

  @override
  String get taskSuccess => '任务成功完成';

  @override
  String taskFailedWithCode(int code) {
    return '任务失败（错误码：$code）';
  }

  @override
  String get taskCancelledByUser => '任务已由用户取消';

  @override
  String taskError(String error) {
    return '错误：$error';
  }

  @override
  String get githubAuthTitle => 'GitHub 身份验证';

  @override
  String get githubPatSaved => 'GitHub 访问令牌已成功保存';

  @override
  String get saveToken => '保存令牌';

  @override
  String get back => '返回';

  @override
  String get next => '下一步';

  @override
  String get aurFull => 'AUR（Arch 用户软件仓库）';

  @override
  String get flatpakFull => 'Flatpak（Flathub）';

  @override
  String get errorPackageNameRequired => '错误：包名不能为空';

  @override
  String errorStartFailed(String error) {
    return '启动失败：$error';
  }

  @override
  String errorUpdateFailed(String error) {
    return '更新失败：$error';
  }

  @override
  String checkUpdateFailed(String error) {
    return '检查更新失败：$error';
  }

  @override
  String errorCleanFailed(String error) {
    return '清理失败：$error';
  }

  @override
  String errorFatalStream(String error) {
    return '致命数据流异常：$error';
  }

  @override
  String errorProcessStart(String error) {
    return '进程启动失败，请检查环境配置：$error';
  }

  @override
  String get taskForcedTerminated => '任务已强制终止';

  @override
  String get aiTimeout => 'AI 连接超时，请稍后重试。';

  @override
  String get aiNoResponse => 'AI 未能提供有效响应。';

  @override
  String get aiParseFailed => 'AI 响应解析失败：格式不正确。';

  @override
  String aiCallFailed(String error) {
    return 'AI 服务调用失败：$error';
  }

  @override
  String errorUpdateAll(String error) {
    return '批量更新失败：$error';
  }

  @override
  String get taskProcessing => '正在处理';

  @override
  String get collapse => '收起';

  @override
  String get expand => '展开';

  @override
  String get all => '全部';

  @override
  String get relatedApps => '相关应用';

  @override
  String get activeSources => '已启用软件源';

  @override
  String get autoDetect => '自动检测';

  @override
  String get addCustomSource => '添加自定义源';

  @override
  String get addCustomSourceDesc =>
      '配置自定义 Flatpak 远程库、AppImage 订阅或 GitHub/Bitu 仓库';

  @override
  String get sourceType => '来源类型';

  @override
  String get githubRepoType => 'GitHub 仓库（owner/repo）';

  @override
  String get bituRepoType => 'Bitu / Bitbucket（工作区/仓库）';

  @override
  String get flatpakRemoteType => 'Flatpak 远程库';

  @override
  String get appImageFeedType => 'AppImage 订阅链接';

  @override
  String get sourceName => '来源名称';

  @override
  String get hintCustomAppName => '例如：my-custom-app';

  @override
  String get repoOwnerRepo => '仓库地址（owner/repo）';

  @override
  String get sourceUrl => '链接';

  @override
  String get hintRepoFormat => '例如：flutter/flutter';

  @override
  String get hintFeedUrl => '例如：https://example.com/feed.json';

  @override
  String get errorNameUrlRequired => '名称和链接/仓库地址不能为空';

  @override
  String get addingCustomSource => '正在添加自定义源...';

  @override
  String get sourceAddSuccess => '来源添加成功！';

  @override
  String get sourceAddFailed => '添加来源失败。';

  @override
  String get autoDetectingSources => '正在自动检测系统中可用的软件源...';

  @override
  String get autoDetectSuccess => '自动检测完成，配置已保存！';

  @override
  String get autoDetectFailed => '保存自动检测结果失败。';

  @override
  String get personalAccessToken => '个人访问令牌';

  @override
  String get copyName => '复制名称';

  @override
  String get nameCopied => '名称已复制到剪贴板';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get tapToCopy => '点击复制';

  @override
  String get language => '界面语言';

  @override
  String get languageSubtitle => '重启应用后生效';

  @override
  String get restartTitleBar => '请重启应用以使标题栏设置生效';

  @override
  String get enableDaemon => '启用后台更新守护进程';

  @override
  String get enableDaemonDesc => '在系统后台定期静默检查应用更新';

  @override
  String get autoUpdate => '静默自动更新';

  @override
  String get autoUpdateDesc => '在后台自动下载并更新所有可升级的软件包';

  @override
  String get checkIntervalTitle => '检查更新频率';

  @override
  String checkIntervalSubtitle(int hours) {
    return '每隔 $hours 小时检查一次';
  }

  @override
  String get typography => '字体与排版';

  @override
  String get fontFamily => '字体系列';

  @override
  String get fontScale => '字体缩放比例';

  @override
  String get systemDefault => '系统默认';

  @override
  String hourValue(int count) {
    return '$count 小时';
  }

  @override
  String get langSimplifiedChinese => '简体中文';

  @override
  String get langTraditionalChinese => '繁體中文';

  @override
  String get langEnglish => '英语（English）';

  @override
  String get langJapanese => '日语（日本語）';

  @override
  String get langSpanish => '西班牙语（Español）';

  @override
  String get taskInProgress => '另一个任务正在进行中';

  @override
  String get trayInitFailedDisabled => '系统托盘初始化失败。已自动关闭后台驻留。';

  @override
  String get errorTitle => '错误';

  @override
  String get appDetailsNotFound => '未找到应用详情';

  @override
  String diskSpaceInfo(String free, String total) {
    return '磁盘空间：$free GB 可用 / $total GB 总计';
  }

  @override
  String cacheTypeInfo(String pacman, String flatpak, String custom) {
    return 'Pacman：$pacman MB | Flatpak：$flatpak MB | 自定义：$custom MB';
  }

  @override
  String get backSemanticsLabel => '返回';

  @override
  String get backSemanticsHint => '返回上一页';

  @override
  String categorySemantics(String name) {
    return '分类：$name';
  }

  @override
  String get temperatureRangeError => '值必须在 0.0 到 2.0 之间';

  @override
  String get enableSystemdService => '启用 systemd 后台更新服务';

  @override
  String get enableSystemdServiceDesc => '允许在应用关闭时通过注册 systemd 定时器来静默检查更新';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get searchHint => '搜尋應用程式、遊戲、工具...';

  @override
  String get featured => '精選';

  @override
  String get forYou => '為您推薦';

  @override
  String get essentialTools => '必備工具';

  @override
  String get hotApps => '熱門應用';

  @override
  String get explore => '探索';

  @override
  String get search => '搜尋';

  @override
  String get settings => '設定';

  @override
  String get downloads => '下載';

  @override
  String get help => '幫助';

  @override
  String get userAccount => '使用者帳戶';

  @override
  String get install => '安裝';

  @override
  String get open => '開啟';

  @override
  String get uninstall => '解除安裝';

  @override
  String get launch => '啟動';

  @override
  String get about => '關於';

  @override
  String get details => '詳情';

  @override
  String get source => '來源';

  @override
  String get variant => '可用版本';

  @override
  String get version => '版本';

  @override
  String get ready => '已安裝';

  @override
  String resultsFound(int count) {
    return '找到 $count 個結果';
  }

  @override
  String get noResults => '暫無搜尋結果';

  @override
  String get searching => '搜尋中...';

  @override
  String get activity => '任務記錄';

  @override
  String get category => '分類';

  @override
  String get packageManager => '套件管理員';

  @override
  String get pacmanOfficial => 'Pacman（官方庫）';

  @override
  String get aurUser => 'AUR（使用者庫）';

  @override
  String get flatpak => 'Flatpak';

  @override
  String get appImage => 'AppImage';

  @override
  String get sourcePriority => '來源優先級（拖曳排序）';

  @override
  String get maxResults => '最大結果數';

  @override
  String get appearance => '介面外觀';

  @override
  String get themeColor => '主題色';

  @override
  String get followSystem => '跟隨系統';

  @override
  String get lightMode => '淺色模式';

  @override
  String get darkMode => '深色模式';

  @override
  String get loggingLevel => '日誌詳細程度';

  @override
  String get saveAndApply => '儲存並套用';

  @override
  String get configSaved => '設定已儲存，部分更改將在重啟後生效';

  @override
  String get configSaveFailed => '儲存設定失敗';

  @override
  String get confirmUninstall => '確認解除安裝';

  @override
  String get confirmInstall => '確認安裝';

  @override
  String confirmActionMsg(String name) {
    return '確定要對 $name 執行此操作嗎？';
  }

  @override
  String get cancel => '取消';

  @override
  String get confirm => '確定';

  @override
  String get terminalOutput => '終端輸出';

  @override
  String get waitingForOutput => '等待終端輸出...';

  @override
  String get screenshots => '應用程式截圖';

  @override
  String get developer => '開發者';

  @override
  String get license => '授權';

  @override
  String get success => '成功';

  @override
  String get failed => '失敗';

  @override
  String get taskCancelled => '任務已取消';

  @override
  String get catDevelopment => '開發工具';

  @override
  String get catMedia => '影音娛樂';

  @override
  String get catInternet => '網際網路';

  @override
  String get catSystem => '系統工具';

  @override
  String get catOffice => '辦公';

  @override
  String get catGames => '遊戲';

  @override
  String get catGraphics => '圖形設計';

  @override
  String get catUtility => '實用工具';

  @override
  String get systemAndWindow => '系統與視窗';

  @override
  String get visitWebsite => '造訪官方網站';

  @override
  String get updates => '更新';

  @override
  String get upToDate => '應用程式已是最新版本';

  @override
  String get checkUpdates => '檢查更新';

  @override
  String foundUpdates(int count) {
    return '發現 $count 個可用更新';
  }

  @override
  String get updateAll => '全部更新';

  @override
  String get notifications => '通知';

  @override
  String get enableNotifications => '啟用通知';

  @override
  String get progressNotifications => '進度通知';

  @override
  String get completionNotifications => '完成通知';

  @override
  String get closeToTray => '關閉時隱藏至系統匣';

  @override
  String get useSystemTitleBar => '使用系統標題列';

  @override
  String get showWindow => '顯示視窗';

  @override
  String get exit => '退出';

  @override
  String trayTooltipUpdates(int count) {
    return 'OmniStore：共有 $count 項可更新';
  }

  @override
  String get trayTooltipUpToDate => 'OmniStore：應用程式已是最新版本';

  @override
  String get updateReminders => '更新提醒';

  @override
  String get maintenance => '維護';

  @override
  String get updateAllPackages => '更新所有套件';

  @override
  String get includeAurUpdates => '全部更新時包含 AUR';

  @override
  String get resetOnboarding => '重置新手引導';

  @override
  String get resetOnboardingConfirm => '確定要重置新手引導嗎？下次啟動時將重新顯示歡迎頁面。';

  @override
  String get checkInterval => '更新檢查間隔（小時）';

  @override
  String get remindMeOfUpdates => '有更新時提醒我';

  @override
  String installingApp(String name) {
    return '正在安裝 $name';
  }

  @override
  String uninstallingApp(String name) {
    return '正在解除安裝 $name';
  }

  @override
  String get installSuccessTitle => '安裝成功';

  @override
  String get uninstallSuccessTitle => '解除安裝成功';

  @override
  String get installFailedTitle => '安裝失敗';

  @override
  String get uninstallFailedTitle => '解除安裝失敗';

  @override
  String get taskCompleted => '任務已完成';

  @override
  String get searchInstalledHint => '搜尋已安裝的應用程式...';

  @override
  String get refresh => '重新整理';

  @override
  String get noActiveTasks => '無進行中的任務';

  @override
  String get currentTask => '目前任務';

  @override
  String get viewLogs => '查看日誌';

  @override
  String get allUpdated => '應用程式已是最新版本';

  @override
  String get update => '更新';

  @override
  String get enableSystemTray => '啟用系統匣';

  @override
  String get systemCleaning => '系統清理';

  @override
  String get systemCleaningDesc => '清理孤兒套件與 pacman 快取';

  @override
  String get systemCleaningSubtitle => '清理孤兒套件與 pacman 快取';

  @override
  String get systemCleaningStarted => '系統清理任務已啟動';

  @override
  String get backupAndExport => '備份與匯出';

  @override
  String get backupAndExportSubtitle => '匯出目前已安裝應用程式列表或從備份匯入';

  @override
  String get export => '匯出';

  @override
  String get import => '匯入';

  @override
  String get selectExportLocation => '選擇匯出位置';

  @override
  String exportSuccess(int count) {
    return '匯出成功：$count 個套件';
  }

  @override
  String exportFailed(String message) {
    return '匯出失敗：$message';
  }

  @override
  String get importBackup => '匯入備份';

  @override
  String importBackupConfirm(int count) {
    return '已從備份中讀取 $count 個套件。是否開始批次恢復？';
  }

  @override
  String get startRecovery => '開始還原';

  @override
  String get mirrorListSaved => '鏡像列表已儲存';

  @override
  String get addMirror => '新增鏡像';

  @override
  String get serverUrl => '伺服器 URL';

  @override
  String get pacmanMirrorManagement => 'Pacman 鏡像管理';

  @override
  String get save => '儲存';

  @override
  String get add => '新增';

  @override
  String get general => '一般';

  @override
  String get advanced => '進階';

  @override
  String get repositories => '軟體存放庫';

  @override
  String get aiSettings => 'AI 助手設定';

  @override
  String get aiEnabled => '啟用 AI 助手';

  @override
  String get aiEnabledDesc => '啟用 AI 驅動的搜尋、應用程式解析及錯誤診斷';

  @override
  String get aiProvider => 'AI 服務商';

  @override
  String get aiEndpoint => 'API 端點';

  @override
  String get aiModel => '模型名稱';

  @override
  String get aiApiKey => 'API 金鑰';

  @override
  String get aiProxy => '網路代理（可選）';

  @override
  String get aiTemperature => '溫度（創意度）';

  @override
  String get aiMaxTokens => '最大回應長度';

  @override
  String get aiTestButton => '測試 AI 連線';

  @override
  String get aiTestSuccess => 'AI 連線成功！';

  @override
  String aiTestFailed(String error) {
    return 'AI 連線失敗：$error';
  }

  @override
  String get aiPromptExplain => '使用 AI 解析';

  @override
  String get aiPromptRecommend => '諮詢 AI 建議';

  @override
  String get aiPromptError => '使用 AI 分析錯誤';

  @override
  String get aiPickDay => 'AI 今日精選';

  @override
  String get aiPickDaySubtitle => '由 OmniStore AI 提供支援';

  @override
  String get aiCompareTitle => 'AI 版本比較';

  @override
  String get aiHealthTitle => 'AI 系統健康診斷';

  @override
  String get aiHealthSubtitle => '針對您的 Arch Linux 的智慧診斷';

  @override
  String get aiCorrection => '您是指：';

  @override
  String get aiThinking => 'AI 正在思考...';

  @override
  String get magicSearch => '智慧搜尋';

  @override
  String get aiChangelogTitle => 'AI 更新摘要';

  @override
  String get aiCliTitle => 'AI 命令生成器';

  @override
  String get aiConflictTitle => 'AI 衝突偵測';

  @override
  String get aiCopyCommand => '複製命令';

  @override
  String get aiCommandCopied => '命令已複製到剪貼簿';

  @override
  String get aiRefineSearch => '使用 AI 精煉搜尋';

  @override
  String get aiExplainUpdate => '解析此更新';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowRestore => '還原';

  @override
  String get windowClose => '關閉';

  @override
  String get omnistore => 'OmniStore';

  @override
  String get installedApps => '已安裝應用程式';

  @override
  String get githubStore => 'GitHub 商店';

  @override
  String get flatpakStore => 'Flatpak 商店';

  @override
  String get locateInstallation => '定位安裝位置';

  @override
  String get delete => '刪除';

  @override
  String get welcomeTitle => '歡迎來到 OmniStore';

  @override
  String get welcomeSubtitle => '為您提供簡單、優雅的 Arch Linux 應用程式管理體驗';

  @override
  String get getStarted => '開始使用';

  @override
  String get skip => '跳過';

  @override
  String get envCheckTitle => '環境檢查';

  @override
  String get envCheckSubtitle => '我們需要確保您的系統已準備就緒';

  @override
  String get envFatalDesc => '您的系統似乎不是基於 Arch 的，這會導致大部分功能不可用。';

  @override
  String get envWarningDesc => '缺少一些必要的組件，我們可以為您自動設定。';

  @override
  String get envOkDesc => '一切就緒！系統環境已完美配置。';

  @override
  String get fixProblems => '一鍵修復/設定';

  @override
  String get continueAnyway => '仍然繼續';

  @override
  String get sourceConfigTitle => '應用程式來源設定';

  @override
  String get sourceConfigSubtitle => '選擇您想要啟用的應用程式來源';

  @override
  String get enableAur => '啟用 AUR（Arch User Repository）';

  @override
  String get yayDesc => '啟用 AUR 需要安裝 yay 助手。';

  @override
  String get aurWarning => '安全警告：AUR 套件由使用者上傳，請確保您信任套件的來源。';

  @override
  String get bootstrapNote => '提示：設定過程可能需要多次輸入管理員密碼。';

  @override
  String get feedbackDesc => '如果您遇到問題，請透過 GitHub 反饋給我們。';

  @override
  String get aiAssistant => 'AI 助手';

  @override
  String get aiAssistantDesc => '啟用 AI 驅動的搜尋、應用程式解析及錯誤診斷';

  @override
  String get aiProviderDesc => '選擇您的 AI 模型來源（本地或雲端）';

  @override
  String get aiEndpointHelper => 'Ollama 預設為 http://localhost:11434';

  @override
  String get aiApiKeyHelper => '如果是 Ollama 則留空，OpenAI 請填入 sk-xxx';

  @override
  String get howToGetApiKey => '如何獲取 API 金鑰？';

  @override
  String get howToGetApiKeyDesc =>
      '1. Ollama（本地）：下載並執行 Ollama，無需金鑰。2. 雲端（OpenAI）：前往服務商官網建立 API Key，然後填入此處。';

  @override
  String get gotIt => '知道了';

  @override
  String get aiOllamaNote =>
      '提示：如果您使用 Ollama，請確保它已在背景執行並開啟了 OLLAMA_ORIGINS=\"*\" 環境變數。';

  @override
  String get enterStore => '進入商店';

  @override
  String get nextStep => '下一步';

  @override
  String get resetCache => '重置快取與歷史記錄';

  @override
  String get resetCacheDesc => '清空搜尋歷史與本地推薦快取';

  @override
  String get resetCacheConfirm => '這將清空您的搜尋歷史和推薦快取。是否繼續？';

  @override
  String get resetting => '正在重置...';

  @override
  String get resetSuccess => '快取與歷史記錄已成功清空';

  @override
  String resetFailed(String error) {
    return '重置失敗：$error';
  }

  @override
  String get ollamaLocal => 'Ollama（本地）';

  @override
  String get openaiCompatible => 'OpenAI 相容';

  @override
  String get googleGemini => 'Google Gemini';

  @override
  String get importPackages => '匯入套件';

  @override
  String importPackagesConfirm(int count) {
    return '已從檔案中讀取 $count 個套件。是否開始批次下載？';
  }

  @override
  String get allDownloads => '全部下載';

  @override
  String get importList => '匯入列表';

  @override
  String get loadError => '無法載入推薦內容，請檢查背景狀態';

  @override
  String get community => '社群';

  @override
  String get official => '官方';

  @override
  String get verified => '官方認證';

  @override
  String installingPkg(String name) {
    return '正在安裝 $name...';
  }

  @override
  String get switchSource => '切換';

  @override
  String get flatpakBetterDesc => '發現此應用程式有 Flatpak 來源，通常更穩定。';

  @override
  String get aiAnalysisPrompt => '發現錯誤日誌，需要 AI 分析嗎？';

  @override
  String get analyzeNow => '立即分析';

  @override
  String get cleanOrphans => '同時清理無用依賴（孤兒套件）';

  @override
  String get securityWarning => '安全風險提示';

  @override
  String get aurSecurityDesc =>
      'AUR（Arch User Repository） 是由社群維護的軟體來源。由於其套件由使用者貢獻，可能存在安全風險。在安裝之前，建議仔細檢查 PKGBUILD。';

  @override
  String get continueInstall => '繼續安裝';

  @override
  String get installInfo => '安裝資訊';

  @override
  String get downloadSize => '下載大小';

  @override
  String get installedSize => '安裝後大小';

  @override
  String dependenciesCount(int count) {
    return '依賴套件（$count）';
  }

  @override
  String get runningInBackground => 'OmniStore 正在背景執行，可透過系統匣圖示開啟';

  @override
  String get clearSearch => '清除搜尋';

  @override
  String get listView => '列表檢視';

  @override
  String get gridView => '網格檢視';

  @override
  String get categories => '分類';

  @override
  String get clearHistory => '清除歷史記錄';

  @override
  String get confirmClearHistory => '確定要刪除所有搜尋歷史嗎？';

  @override
  String get viewMore => '查看更多';

  @override
  String get logDebug => '除錯（DEBUG）';

  @override
  String get logInfo => '資訊（INFO）';

  @override
  String get logWarning => '警告（WARNING）';

  @override
  String get logError => '錯誤（ERROR）';

  @override
  String get notificationTitle => '發現可用更新';

  @override
  String notificationBody(int count) {
    return '您的系統中有 $count 個應用程式可以更新';
  }

  @override
  String get preparingUpdate => '正在準備更新...';

  @override
  String get processing => '正在處理';

  @override
  String get clear => '清除';

  @override
  String get retry => '重試';

  @override
  String get aiResponseFailed => 'AI 回應失敗。';

  @override
  String get aiAnalysisFailed => 'AI 分析失敗。';

  @override
  String cannotConnectToBackend(String error) {
    return '無法連線至後端服務：$error';
  }

  @override
  String get taskInitializing => '正在初始化任務...';

  @override
  String get taskStarting => '正在啟動...';

  @override
  String get taskSuccess => '任務成功完成';

  @override
  String taskFailedWithCode(int code) {
    return '任務失敗（錯誤碼：$code）';
  }

  @override
  String get taskCancelledByUser => '任務已由使用者取消';

  @override
  String taskError(String error) {
    return '錯誤：$error';
  }

  @override
  String get githubAuthTitle => 'GitHub 身份驗證';

  @override
  String get githubPatSaved => 'GitHub 存取權杖已成功儲存';

  @override
  String get saveToken => '儲存權杖';

  @override
  String get back => '返回';

  @override
  String get next => '下一步';

  @override
  String get aurFull => 'AUR（Arch 使用者軟體存放庫）';

  @override
  String get flatpakFull => 'Flatpak（Flathub）';

  @override
  String get errorPackageNameRequired => '錯誤：套件名稱不能為空';

  @override
  String errorStartFailed(String error) {
    return '啟動失敗：$error';
  }

  @override
  String errorUpdateFailed(String error) {
    return '更新失敗：$error';
  }

  @override
  String checkUpdateFailed(String error) {
    return '檢查更新失敗：$error';
  }

  @override
  String errorCleanFailed(String error) {
    return '清理失敗：$error';
  }

  @override
  String errorFatalStream(String error) {
    return '致命資料串流異常：$error';
  }

  @override
  String errorProcessStart(String error) {
    return '程序啟動失敗，請檢查環境設定：$error';
  }

  @override
  String get taskForcedTerminated => '任務已強制終止';

  @override
  String get aiTimeout => 'AI 連線逾時，請稍後重試。';

  @override
  String get aiNoResponse => 'AI 未能提供有效回應。';

  @override
  String get aiParseFailed => 'AI 回應解析失敗：格式不正確。';

  @override
  String aiCallFailed(String error) {
    return 'AI 服務呼叫失敗：$error';
  }

  @override
  String errorUpdateAll(String error) {
    return '批次更新失敗：$error';
  }

  @override
  String get taskProcessing => '正在處理';

  @override
  String get collapse => '收起';

  @override
  String get expand => '展開';

  @override
  String get all => '全部';

  @override
  String get relatedApps => '相關應用';

  @override
  String get activeSources => '已啟用軟體源';

  @override
  String get autoDetect => '自動偵測';

  @override
  String get addCustomSource => '新增自訂源';

  @override
  String get addCustomSourceDesc =>
      '設定自訂 Flatpak 遠端庫、AppImage 訂閱或 GitHub/Bitu 存放庫';

  @override
  String get sourceType => '來源類型';

  @override
  String get githubRepoType => 'GitHub 存放庫（owner/repo）';

  @override
  String get bituRepoType => 'Bitu / Bitbucket（工作區/存放庫）';

  @override
  String get flatpakRemoteType => 'Flatpak 遠端庫';

  @override
  String get appImageFeedType => 'AppImage 訂閱連結';

  @override
  String get sourceName => '來源名稱';

  @override
  String get hintCustomAppName => '例如：my-custom-app';

  @override
  String get repoOwnerRepo => '存放庫地址（owner/repo）';

  @override
  String get sourceUrl => '連結';

  @override
  String get hintRepoFormat => '例如：flutter/flutter';

  @override
  String get hintFeedUrl => '例如：https://example.com/feed.json';

  @override
  String get errorNameUrlRequired => '名稱和連結/存放庫地址不能為空';

  @override
  String get addingCustomSource => '正在新增自訂源...';

  @override
  String get sourceAddSuccess => '來源新增成功！';

  @override
  String get sourceAddFailed => '新增來源失敗。';

  @override
  String get autoDetectingSources => '正在自動偵測系統中可用的軟體源...';

  @override
  String get autoDetectSuccess => '自動偵測完成，設定已儲存！';

  @override
  String get autoDetectFailed => '儲存自動偵測結果失敗。';

  @override
  String get personalAccessToken => '個人存取權杖';

  @override
  String get copyName => '複製名稱';

  @override
  String get nameCopied => '名稱已複製到剪貼簿';

  @override
  String get copiedToClipboard => '已複製到剪貼簿';

  @override
  String get tapToCopy => '點擊複製';

  @override
  String get language => '介面語言';

  @override
  String get languageSubtitle => '重啟應用程式後生效';

  @override
  String get restartTitleBar => '請重啟應用程式以使標題列設定生效';

  @override
  String get enableDaemon => '啟用背景更新守護程序';

  @override
  String get enableDaemonDesc => '在系統背景定期靜默檢查應用程式更新';

  @override
  String get autoUpdate => '靜默自動更新';

  @override
  String get autoUpdateDesc => '在背景自動下載並更新所有可升級的套件';

  @override
  String get checkIntervalTitle => '檢查更新頻率';

  @override
  String checkIntervalSubtitle(int hours) {
    return '每隔 $hours 小時檢查一次';
  }

  @override
  String get typography => '字體與排版';

  @override
  String get fontFamily => '字體系列';

  @override
  String get fontScale => '字體縮放比例';

  @override
  String get systemDefault => '系統預設';

  @override
  String hourValue(int count) {
    return '$count 小時';
  }

  @override
  String get langSimplifiedChinese => '簡體中文';

  @override
  String get langTraditionalChinese => '繁體中文';

  @override
  String get langEnglish => '英語（English）';

  @override
  String get langJapanese => '日語（日本語）';

  @override
  String get langSpanish => '西班牙語（Español）';

  @override
  String get taskInProgress => '另一個任務正在進行中';

  @override
  String get trayInitFailedDisabled => '系統匣初始化失敗。已自動關閉背景駐留。';

  @override
  String get errorTitle => '錯誤';

  @override
  String get appDetailsNotFound => '未找到應用程式詳情';

  @override
  String diskSpaceInfo(String free, String total) {
    return '磁碟空間：$free GB 可用 / $total GB 總計';
  }

  @override
  String cacheTypeInfo(String pacman, String flatpak, String custom) {
    return 'Pacman：$pacman MB | Flatpak：$flatpak MB | 自定義：$custom MB';
  }

  @override
  String get backSemanticsLabel => '返回';

  @override
  String get backSemanticsHint => '返回上一頁';

  @override
  String categorySemantics(String name) {
    return '分類：$name';
  }

  @override
  String get temperatureRangeError => '值必須在 0.0 到 2.0 之間';

  @override
  String get enableSystemdService => '啟用 systemd 後台更新服務';

  @override
  String get enableSystemdServiceDesc => '允許在應用程式關閉時透過註冊 systemd 定時器來靜默檢查更新';
}
