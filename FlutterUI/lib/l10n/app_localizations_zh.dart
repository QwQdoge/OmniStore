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
  String get downloads => '任务与更新';

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
  String get source => '软件源';

  @override
  String get variant => '分发版本';

  @override
  String get version => '版本';

  @override
  String get ready => '已安装';

  @override
  String resultsFound(int count) {
    return '$count 个结果';
  }

  @override
  String get noResults => '未找到相关结果';

  @override
  String get searching => '正在搜索...';

  @override
  String get activity => '任务动态';

  @override
  String get category => '分类';

  @override
  String get packageManager => '软件包管理器';

  @override
  String get pacmanOfficial => 'Pacman（官方软件源）';

  @override
  String get pacmanBrowsingNoAuthorization =>
      '浏览、搜索、查看详情和检查 Pacman 更新均不需要账号或管理员认证；只有修改系统时才会请求授权。';

  @override
  String get aurUser => 'AUR（用户软件源）';

  @override
  String get flatpak => 'Flatpak';

  @override
  String get appImage => 'AppImage';

  @override
  String get sourcePriority => '软件源优先级（拖动排序）';

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
  String get loggingLevel => '日志级别';

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
  String get license => '许可证';

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
  String get upToDate => '应用已是最新版本';

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
    return 'OmniStore：发现 $count 个可用更新';
  }

  @override
  String get trayTooltipUpToDate => 'OmniStore：应用已是最新版本';

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
  String get noActiveTasks => '暂无进行中的任务';

  @override
  String get currentTask => '当前任务';

  @override
  String get viewLogs => '查看日志';

  @override
  String get allUpdated => '未发现软件包更新';

  @override
  String get update => '更新';

  @override
  String updatingSourcePackages(String source) {
    return '正在更新 $source 软件包…';
  }

  @override
  String sourceUpdateFailed(String source) {
    return '$source 更新失败';
  }

  @override
  String get enabledSourcesUpdated => '所有已启用的软件源均已更新';

  @override
  String get enableSystemTray => '启用系统托盘';

  @override
  String get systemCleaning => '系统清理';

  @override
  String get system => '系统';

  @override
  String get clean => '清理';

  @override
  String get systemCleaningDesc => '移除孤立软件包并清空 Pacman 缓存（需要管理员授权）';

  @override
  String get systemCleaningSubtitle => '清理孤立软件包与 pacman 缓存';

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
    return '已从备份中读取 $count 个软件包。是否开始批量还原？';
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
  String get aiPromptExplain => 'AI 解析';

  @override
  String get aiPromptRecommend => 'AI 建议';

  @override
  String get aiPromptError => 'AI 分析错误';

  @override
  String get aiPickDay => 'AI 今日精选';

  @override
  String get aiPickDaySubtitle => '由 OmniStore AI 提供支持';

  @override
  String get aiCompareTitle => 'AI 版本对比';

  @override
  String get aiHealthTitle => 'AI 系统健康报告';

  @override
  String get aiHealthSubtitle => 'Arch Linux 智能诊断报告';

  @override
  String get aiCorrection => '您是指：';

  @override
  String get aiThinking => 'AI 正在思考...';

  @override
  String get magicSearch => '智能搜索';

  @override
  String get aiChangelogTitle => 'AI 更新摘要';

  @override
  String get aiCliTitle => 'AI 命令生成器';

  @override
  String get aiConflictTitle => 'AI 冲突检测';

  @override
  String get aiCopyCommand => '复制命令';

  @override
  String get aiRefineSearch => '使用 AI 优化搜索';

  @override
  String get aiExplainUpdate => 'AI 解析此更新';

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
  String get welcomeSubtitle => '提供简单、优雅的 Arch Linux 应用管理体验';

  @override
  String get getStarted => '开始使用';

  @override
  String get skip => '跳过';

  @override
  String get envCheckTitle => '环境检查';

  @override
  String get envCheckSubtitle => '确保系统已准备就绪';

  @override
  String get envFatalDesc => '当前系统不是 Arch Linux，核心功能受限。';

  @override
  String get envWarningDesc => '缺少必要组件，将进行自动配置。';

  @override
  String get envOkDesc => '系统状态良好，一切就绪！';

  @override
  String get fixProblems => '一键修复/配置';

  @override
  String get continueAnyway => '仍然继续';

  @override
  String get sourceConfigTitle => '软件源配置';

  @override
  String get sourceConfigSubtitle => '选择 OmniStore 可以搜索的软件来源';

  @override
  String get enableAur => '启用 AUR (Arch User Repository)';

  @override
  String get yayDesc => '启用 AUR 需要安装 yay 助手。';

  @override
  String get aurWarning => '安全警告：AUR 软件包由社区用户贡献，请确保信任其来源。';

  @override
  String get bootstrapNote => '浏览无需任何授权；只有配置需要修改系统时才会请求管理员授权。';

  @override
  String get feedbackDesc => '通过 GitHub 反馈遇到的问题。';

  @override
  String get aiAssistant => 'AI 助手';

  @override
  String get aiAssistantDesc => '启用 AI 驱动的搜索、应用解析及错误诊断';

  @override
  String get aiProviderDesc => '选择 AI 模型来源（本地或云端）';

  @override
  String get aiEndpointHelper => 'Ollama 默认为 http://localhost:11434';

  @override
  String get aiApiKeyHelper => 'Ollama 无需密钥，OpenAI 需填写 sk-xxx';

  @override
  String get howToGetApiKey => '如何获取 API 密钥？';

  @override
  String get howToGetApiKeyDesc =>
      '1. Ollama (本地)：直接运行，无需密钥。2. 云端 (OpenAI)：前往官网创建并填写密钥。';

  @override
  String get gotIt => '知道了';

  @override
  String get aiOllamaNote => '确保 Ollama 已在后台运行并启用了 OLLAMA_ORIGINS=\"*\" 环境变量。';

  @override
  String get enterStore => '进入商店';

  @override
  String get nextStep => '下一步';

  @override
  String get resetCache => '重置缓存与历史记录';

  @override
  String get resetCacheDesc => '清空搜索历史与本地推荐缓存';

  @override
  String get resetCacheConfirm => '将清空搜索历史和推荐缓存。确认继续？';

  @override
  String get resetting => '正在重置...';

  @override
  String get resetSuccess => '缓存与历史记录已成功清空';

  @override
  String resetFailed(String error) {
    return '重置失败：$error';
  }

  @override
  String get ollamaLocal => 'Ollama (本地)';

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
  String get flatpakBetterDesc => '发现此应用有 Flatpak 软件源，通常更稳定。';

  @override
  String get aiAnalysisPrompt => '发现错误日志，需要 AI 分析吗？';

  @override
  String get analyzeNow => '立即分析';

  @override
  String get cleanOrphans => '清理孤立软件包';

  @override
  String get securityWarning => '安全风险提示';

  @override
  String get aurSecurityDesc =>
      'AUR 是由社区维护的软件源。由于任何人都可以上传软件包，其中可能包含不安全的代码。建议在安装前仔细检查 PKGBUILD。';

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
    return '依赖项（$count）';
  }

  @override
  String get runningInBackground => 'OmniStore 正在后台运行，可通过系统托盘图标打开';

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
  String get clearHistoryShort => '清空历史';

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
    return '有 $count 个应用可以更新';
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
  String get searchFailedSubtitle => '无法连接软件源。请检查网络连接后重试。';

  @override
  String pluginCapabilities(int count) {
    return '$count 项能力';
  }

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
  String get aurFull => 'AUR（Arch 用户软件源）';

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
  String get addCustomSource => '添加自定义软件源';

  @override
  String get addCustomSourceDesc =>
      '配置自定义 Pacman/Flatpak 仓库、AppImage 订阅或 GitHub/Bitu 软件源';

  @override
  String get pacmanRepoType => 'Pacman 软件仓库';

  @override
  String get pacmanRepoSafety =>
      '仅接受 HTTPS 仓库并强制软件包签名。OmniStore 不会下载签名密钥，也不会运行 pacman -Sy；该来源会在下一次完整系统升级时生效。';

  @override
  String get sourceType => '软件源类型';

  @override
  String get githubRepoType => 'GitHub 仓库（owner/repo）';

  @override
  String get bituRepoType => 'Bitu / Bitbucket（工作区/仓库）';

  @override
  String get flatpakRemoteType => 'Flatpak 远程软件源';

  @override
  String get appImageFeedType => 'AppImage 订阅链接';

  @override
  String get sourceName => '软件源名称';

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
  String get errorNameUrlRequired => '名称和链接/软件源地址不能为空';

  @override
  String get addingCustomSource => '正在添加自定义软件源...';

  @override
  String get sourceAddSuccess => '软件源添加成功！';

  @override
  String get sourceAddFailed => '添加软件源失败。';

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
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get tapToCopy => '点击复制';

  @override
  String get language => '界面语言';

  @override
  String get languageSubtitle => '重启应用后生效';

  @override
  String get restartTitleBar => '重启应用后标题栏设置生效';

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
    return '每隔 $hours 小时自动检查一次';
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

  @override
  String get taskHistory => '任务历史记录';

  @override
  String get unknownApp => '未知应用';

  @override
  String get taskSuccessMsg => '已成功完成';

  @override
  String failureReason(String message) {
    return '失败原因：$message';
  }

  @override
  String get noPackagesAvailable => '暂无可用软件包';

  @override
  String get noDescription => '暂无说明';

  @override
  String get viewDetails => '查看详情';

  @override
  String get ok => '确定';

  @override
  String get checkNetwork => '请检查网络连接并重试';

  @override
  String get githubStoreSubtitle => '直接从 GitHub Releases 发现并下载应用';

  @override
  String get searchGithubHint => '搜索 GitHub 仓库...';

  @override
  String get recommended => '推荐';

  @override
  String get rankings => '排行榜';

  @override
  String get trending => '热度榜';

  @override
  String get latestUpdates => '最新更新';

  @override
  String get searchNoResultsSubtitle => '请尝试其他关键词，或启用更多软件源';

  @override
  String get pluginsAndSources => '插件与软件源';

  @override
  String get refreshPlugins => '刷新插件';

  @override
  String get noPluginsFound => '未发现插件';

  @override
  String get builtin => '内置';

  @override
  String get legacy => '旧版';

  @override
  String get pluginUpdated => '插件已更新';

  @override
  String get pluginUpdateFailed => '插件更新失败';

  @override
  String get pluginRemoved => '插件已移除';

  @override
  String get pluginRemovalFailed => '插件移除失败';

  @override
  String get removePlugin => '移除插件';

  @override
  String get managed => '已托管';

  @override
  String get readOnly => '只读';

  @override
  String get installationDecisionTitle => '安装决策助手';

  @override
  String recommendedSource(String source) {
    return '推荐软件源：$source';
  }

  @override
  String get preflightChecks => '安装前检查';

  @override
  String get potentialRisks => '风险提示';

  @override
  String get continueInstallation => '继续安装';

  @override
  String get changeRecommendation => '换一个推荐';

  @override
  String get aiPickDisclaimer => '推荐结果仅供参考：基于您的搜索习惯和当前软件源配置生成，不会影响您的具体安装选项。';

  @override
  String get quickStart => '快速开始';

  @override
  String get importListSubtitle => '从列表导入常用软件包';

  @override
  String get emptyTrendingMessage => '暂无热门数据；网络连接恢复后将自动更新。';

  @override
  String get emptyRecommendationsMessage => '继续搜索或安装应用后，此处将显示个性化建议。';

  @override
  String get aiPickFallbackMessage => '暂时无法生成个性化推荐。可浏览编辑精选或稍后重试。';

  @override
  String get meoarchAccount => 'MeoArch 账户';

  @override
  String get defaultUser => '用户';

  @override
  String get signOut => '退出登录';

  @override
  String get syncStatus => '同步状态';

  @override
  String get syncStatusSubtitle => '点按备份 OmniStore 应用列表';

  @override
  String get manageAccount => '管理账户';

  @override
  String get manageAccountSubtitle => '安全、多因素验证与会话管理';

  @override
  String get signInTitle => '登录 MeoArch';

  @override
  String get signInSubtitle => '跨设备同步应用、设置和收藏';

  @override
  String get email => '邮箱';

  @override
  String get password => '密码';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get signIn => '登录';

  @override
  String get createAccount => '创建 MeoArch 账户';

  @override
  String get orDivider => '或';

  @override
  String get continueWithGoogle => '使用 Google 账号继续';

  @override
  String get continueWithGitHub => '使用 GitHub 账号继续';

  @override
  String get enterEmailAndPassword => '请输入邮箱和密码。';

  @override
  String signInFailed(String message) {
    return '登录失败：$message';
  }

  @override
  String signInError(String message) {
    return '登录出错：$message';
  }

  @override
  String get githubIntegration => 'GitHub 集成';

  @override
  String get configurePat => 'GitHub 访问令牌（可选）';

  @override
  String get patHelperText => '请提供 GitHub Classic PAT 或 Fine-grained 令牌。';

  @override
  String get featuredSubtitle => '由 OmniStore 维护，离线时也始终可见';

  @override
  String get editorPicks => '编辑推荐';

  @override
  String get checkingEnvStatus => '正在检查环境状态...';

  @override
  String get envDetailsFailed => '获取环境详情失败。';

  @override
  String get bootstrapProgress => '环境配置进度：';

  @override
  String get systemDetails => '系统详情：';

  @override
  String get aiIntegrationDesc => '开启智能集成与辅助功能';

  @override
  String get ollamaLocalOffline => 'Ollama (本地 / 离线)';

  @override
  String get openaiCloud => 'OpenAI API (云端)';

  @override
  String get testConnection => '测试连接';

  @override
  String get githubSearchFailed => 'GitHub 搜索失败';

  @override
  String get githubStoreUnavailable => 'GitHub 商店暂不可用';

  @override
  String get noGithubReposFound => '未找到 GitHub 软件仓库';

  @override
  String get pullToRefreshCategory => '下拉刷新或尝试其他分类。';

  @override
  String sourceFilterSemantics(String name) {
    return '按软件源筛选：$name';
  }

  @override
  String get meoChannelTitle => 'Meo 更新通道';

  @override
  String get meoChannelSubtitle => '从当前 pacman 软件源顺序读取';

  @override
  String get meoChannelBetaNotice =>
      'Beta 通道可优先体验最新的 Meo 组件。Arch 系统软件包仍保持默认软件源。';

  @override
  String get meoChannelStableNotice => 'Stable 通道接收经过完整测试的 MeoArch 稳定发布版本。';

  @override
  String repoPriority(String repos) {
    return '软件源优先级：$repos';
  }

  @override
  String get betaWarningPanel =>
      'Beta 为手动开启选项，不建议在生产环境或关键系统中使用。Stable 仍为后备软件源。';

  @override
  String downgradeReviewPending(int count) {
    return '已配置 Stable 通道，但仍有 $count 个 Meo 软件包降级项需要审查。';
  }

  @override
  String get reviewDowngrades => '审查降级项';

  @override
  String get switchToStable => '切换至稳定版';

  @override
  String downgradeNotice(String packages) {
    return '以下官方 Meo 软件包需要降级至稳定版本。Arch 及第三方软件包不会被降级。\n\n$packages';
  }

  @override
  String get channelStable => '稳定版';

  @override
  String get channelBeta => 'Beta 版';

  @override
  String get download => '下载';

  @override
  String get systemAiProviderLabel => '系统 AI 连接（KWallet / 推荐）';

  @override
  String get systemAiSharedConnectionLabel => '系统共享连接';

  @override
  String get systemAiConnectionHelper =>
      '密钥由 Meo Account 从 KWallet 读取，OmniStore 无法读取明文。';

  @override
  String get systemAiLoadingTitle => '正在读取系统 AI 连接';

  @override
  String get systemAiMetadataOnly => '只读取名称、端点和默认模型，不读取密钥。';

  @override
  String get systemAiLoadErrorTitle => '无法读取系统 AI 连接';

  @override
  String get systemAiSelectLabel => '此设备的 AI 连接';

  @override
  String get meoSettingsOpenFailed => '无法打开 Meo Settings。';

  @override
  String get manageInMeoSettings => '在 Meo Settings 中管理';

  @override
  String get systemAiNoConnections => '还没有系统 AI 连接；请先在 Meo Settings 中添加。';

  @override
  String get systemAiLoadFailed =>
      '无法读取系统 AI 连接；请在 Meo Settings 的“账号与安全”中检查配置。';

  @override
  String get systemAiInvalidCatalog => '系统 AI 服务返回了无效的模型目录。';

  @override
  String get systemAiInvalidConsent => '系统 AI 服务没有返回有效的授权摘要。';

  @override
  String get systemAiConsentExpired => '系统 AI 授权摘要无效或已经过期。';

  @override
  String get systemAiInvalidResponse => '系统 AI 服务没有返回有效文本。';

  @override
  String get systemAiUnsupported => '当前平台不支持系统 AI 服务。';

  @override
  String get systemAiOperationFailed => '系统 AI 操作失败。';

  @override
  String get systemAiTimeout => '系统 AI 操作超时。';

  @override
  String get systemAiUnavailable => '无法连接 Meo Account 系统 AI 服务。';

  @override
  String get systemAiTestPurpose => '测试 OmniStore 的系统 AI 连接';

  @override
  String get aiConsentCancelled => '你取消了这次 AI 请求。';

  @override
  String get chooseSystemAiConnection => '请先在 OmniStore 设置中选择系统 AI 连接。';

  @override
  String get chooseAccountAiConnection => '请先在 OmniStore 设置中选择账号 AI 连接。';

  @override
  String get aiConfigUnavailable => 'AI 配置不可用。';

  @override
  String get aiNotEnabled => 'AI 功能尚未启用。';

  @override
  String get aiAccountProviderHint =>
      'Account 只代为调用你已保存的连接；API 密钥不会下发到 OmniStore。';

  @override
  String get aiSystemProviderHint =>
      '由 Meo Account 从 KWallet 调用；OmniStore 只看到连接信息和最终结果。';

  @override
  String get aiOllamaProviderHint => 'Ollama 仅连接本机服务；不需要 API 密钥。';

  @override
  String get aiCompatibleProviderHint => '仅使用你信任的 HTTPS 兼容端点；密钥仍保存在本机安全凭据库。';

  @override
  String get aiLocalKeyProviderHint =>
      '此服务商的密钥单独保存在 Secret Service/KWallet，无法读回明文。';

  @override
  String get meoAccountOpenFailed => '无法打开 Meo Account。';

  @override
  String get secureCredentialWriteFailed => '无法写入系统安全凭据库。';

  @override
  String get modelsNoneFound => '服务正在运行，但没有发现已安装或可用的模型。';

  @override
  String get modelsAutofilled => '已发现并自动填入模型。';

  @override
  String get modelsFoundChoose => '已发现模型；请选择后再测试，OmniStore 不会根据名称猜测能力。';

  @override
  String get apiKeyRequired => '请先填写新的 API 密钥。';

  @override
  String get secureCredentialSaved => 'API 密钥已写入系统安全凭据库。';

  @override
  String get localApiKeyDeleted => '本地 API 密钥已删除。';

  @override
  String get secureCredentialUnavailable => '无法访问系统安全凭据库。';

  @override
  String get signInMeoAccount => '登录 Meo Account';

  @override
  String get signInMeoAccountDetail =>
      '登录后即可选择账号中加密保存的 AI 连接；API 密钥不会下发到 OmniStore。';

  @override
  String get accountAiLoading => '正在读取账号 AI 连接';

  @override
  String get accountAiMetadataOnly => '只读取名称、服务商和密钥掩码。';

  @override
  String get accountAiLoadError => '无法读取账号 AI 连接';

  @override
  String get accountAiNone => '账号中还没有 AI 连接';

  @override
  String get accountAiNoneDetail => '前往 Account 填写你自己的 API 密钥并安全保存，然后回到这里刷新。';

  @override
  String get connect => '去连接';

  @override
  String get accountAiSelectLabel => '账号 AI 连接';

  @override
  String get accountAiConnectionHelper =>
      '密钥只在 Account Edge broker 内解密，OmniStore 不可读取。';

  @override
  String get manageAiConnections => '管理 AI 连接';

  @override
  String get aiPerRequestConsentDetail =>
      '每次发送前，OmniStore 都会显示服务商、模型、用途、数据类别、完整内容和请求指纹，并要求仅同意这一次。';

  @override
  String get aiEnabledConsentDesc => '默认关闭；开启后每次发送仍需单独确认。';

  @override
  String providerLocalSecureKey(String provider) {
    return '$provider（本地安全密钥）';
  }

  @override
  String get providerCompatibleHttps => 'OpenAI Compatible（自定义 HTTPS）';

  @override
  String get providerMeoAccount => 'Meo Account';

  @override
  String get ollamaEndpointSafety => '默认连接本机 Ollama；请保留回环地址以避免意外访问局域网服务。';

  @override
  String get compatibleEndpointSafety => '仅填写你信任的 HTTPS 兼容端点，不包含密钥或查询参数。';

  @override
  String get accountModelOverride => '账号模型';

  @override
  String get accountModelDefaultHelper => '留空会使用所选 Account AI 连接的默认模型。';

  @override
  String get modelReviewHelper => '实际模型会在每次发送前再次展示，供你确认。';

  @override
  String get detectLocalModels => '检测本机模型并自动填入';

  @override
  String get readModelCatalog => '读取模型目录';

  @override
  String get installOllamaWithOmniStore => '通过 OmniStore 安装 Ollama';

  @override
  String get chooseDiscoveredModel => '选择已发现的模型';

  @override
  String get localKeyStored => '当前服务商已有独立安全密钥';

  @override
  String get localKeyNotStored => '当前服务商尚未保存 API 密钥';

  @override
  String get localKeysHelper =>
      '每个服务商分别保存在 Secret Service/KWallet；只能替换或删除，不能读回明文。';

  @override
  String get newApiKeyLabel => '新的 API 密钥（写入后清空）';

  @override
  String get newApiKeyHelper => '仅填写要替换的新密钥；保存后不能读取或复制旧密钥。';

  @override
  String get hideInput => '隐藏输入';

  @override
  String get showInput => '显示输入';

  @override
  String get saveOrReplace => '安全保存 / 替换';

  @override
  String get deleteLocalKey => '删除本地密钥';

  @override
  String get temperatureHelper => '0–2；较低数值通常更稳定，范围外不会保存。';

  @override
  String get aiTestScopeHelper => '测试只验证当前连接，不会改变“启用 AI 辅助”开关；实际发送仍需单次确认。';

  @override
  String get meoUpdateChannel => 'Meo 更新通道';

  @override
  String get meoUpdateChannelSubtitle => '按当前生效的 Pacman 软件源读取';

  @override
  String get meoChannelChecking => '正在检查更新通道…';

  @override
  String get meoChannelStable => '稳定版';

  @override
  String get meoChannelBeta => '测试版';

  @override
  String get meoChannelBetaSummary => '抢先使用较新的 Meo 组件；Arch 系统软件包仍使用其正常软件源。';

  @override
  String get meoChannelStableSummary => '使用经过完整测试的 MeoArch 发布列车。';

  @override
  String meoChannelRepositoryPriority(String repositories) {
    return '软件源优先级：$repositories';
  }

  @override
  String meoChannelDowngradePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选择稳定版，但仍有 $count 个 Meo 软件包降级需要你确认。',
      one: '已选择稳定版，但仍有 1 个 Meo 软件包降级需要你确认。',
    );
    return '$_temp0';
  }

  @override
  String get meoChannelReviewDowngrades => '查看降级项目';

  @override
  String get meoChannelSwitchToStable => '切换到稳定版';

  @override
  String get meoChannelRollbackPreviewInvalid => '这份稳定版回退预览已失效。请刷新后重新查看。';

  @override
  String meoChannelDowngradeDialog(String packages) {
    return '以下官方 Meo 软件包将切换到稳定版。不会降级 Arch 或第三方软件包。\\n\\n$packages';
  }

  @override
  String get aiConsentTitle => '确认这一次 AI 请求';

  @override
  String get aiConsentIntro => '请先查看以下内容。你的确认只适用于这一次请求及其指纹。';

  @override
  String get aiConsentProvider => '服务商';

  @override
  String get aiConsentDestination => '发送到';

  @override
  String get aiConsentModel => '模型';

  @override
  String get aiConsentPurpose => '用途';

  @override
  String get aiConsentDataCategories => '将发送的数据';

  @override
  String get aiConsentCharacters => '字符数';

  @override
  String get aiConsentFingerprint => '请求指纹';

  @override
  String get aiConsentReviewContent => '查看将发送的内容';

  @override
  String get aiConsentSystemInstruction => '系统指令';

  @override
  String get aiConsentUserContent => '你的内容';

  @override
  String aiConsentConfirmWithProvider(String provider) {
    return '我确认以上内容将发送给 $provider。';
  }

  @override
  String get aiConsentKeyNotExposed => 'API 密钥不属于这段提示内容，也不会在这里显示。';

  @override
  String get aiConsentDeny => '暂不发送';

  @override
  String get aiConsentAllowOnce => '确认并发送一次';

  @override
  String get aiConsentCategoryAppName => '应用名称';

  @override
  String get aiConsentCategoryAppDescription => '应用描述';

  @override
  String get aiConsentCategoryVersionMetadata => '版本信息';

  @override
  String get aiConsentCategoryPackageSource => '软件源';

  @override
  String get aiConsentCategoryPackageVariants => '可选安装版本';

  @override
  String get aiConsentCategoryPreferenceRequest => '偏好请求';

  @override
  String get aiConsentCategorySearchQuery => '搜索关键词';

  @override
  String get aiConsentCategorySystemEnvironment => '系统环境摘要';

  @override
  String get aiConsentCategoryErrorLog => '错误日志';

  @override
  String get aiConsentCategoryRecommendationRequest => '推荐需求';

  @override
  String get aiConsentCategoryConnectionTest => '连接测试数据';

  @override
  String get githubLoadErrorDetail => '无法加载 GitHub 仓库。请检查网络后重试。';

  @override
  String get githubSearchErrorDetail => '无法搜索 GitHub 仓库。请检查网络后重试。';

  @override
  String get flatpakLoadErrorDetail => '无法加载 Flatpak 应用。请检查 Flathub 和网络连接后重试。';

  @override
  String appCardSemantics(String name) {
    return '应用：$name';
  }

  @override
  String get diskSize => '磁盘占用';

  @override
  String diskSizeWithConfidence(String confidence) {
    return '磁盘占用（$confidence）';
  }

  @override
  String get accountAiSignInRequired => '请先登录 Meo Account，再使用账号 AI。';

  @override
  String get accountAiNoDefaultModel => '此 AI 连接没有默认模型。请先在设置中选择模型。';

  @override
  String get accountAiInvalidConsent => '账号 AI 服务没有返回有效的授权摘要。';

  @override
  String get accountAiConsentExpired => 'AI 授权摘要无效或已过期。';

  @override
  String get accountAiInvalidResponse => 'AI 服务没有返回有效内容。';

  @override
  String get accountAiTestPurpose => '测试 OmniStore 的账号 AI 连接';

  @override
  String get accountAiInvalidDestination => '账号 AI 连接的目标地址无效。';

  @override
  String get accountAiConnectionNotFound => '所选 AI 连接不可用。请在设置中重新选择。';

  @override
  String get accountAiInvalidData => '账号 AI 服务返回了无效数据。';

  @override
  String get accountAiUnavailable => '账号 AI 服务暂时不可用。';

  @override
  String get accountAiRequestDenied => '账号 AI 请求被拒绝。请重新登录后再试。';

  @override
  String get accountAiConnectionFailed => '无法连接账号 AI 服务。';

  @override
  String get localAiUnsupportedModelDiscovery => '此连接不支持本机模型发现。';

  @override
  String get localAiCredentialStoreUnavailable => '无法打开安全凭据库。请解锁 KWallet 后重试。';

  @override
  String get localAiApiKeyRequired => '请先为当前服务商安全保存 API 密钥。';

  @override
  String get localAiCatalogTooLarge => '模型目录响应过大。';

  @override
  String get localAiInvalidCatalog => '模型目录返回了无效数据。';

  @override
  String get localAiCatalogUnavailable => '无法读取模型目录。请确认服务正在运行。';

  @override
  String get localAiUnsupportedConnection => '不支持这种本地 AI 连接类型。';

  @override
  String get localAiInvalidModel => '请输入有效的模型名称。';

  @override
  String get localAiInvalidPurpose => 'AI 请求用途无效。';

  @override
  String get localAiInvalidInput => 'AI 输入为空或过大。';

  @override
  String get localAiInvalidDataCategories => 'AI 数据类别无效。';

  @override
  String get localAiApiKeyInvalid => '安全凭据库中没有此服务商的有效 API 密钥。';

  @override
  String get localAiDestinationChanged => 'AI 目标地址在确认后发生变化，请求已被拦截。';

  @override
  String get localAiResponseTooLarge => 'AI 服务响应过大。';

  @override
  String get localAiInvalidResponse => 'AI 服务返回了无效数据。';

  @override
  String get localAiNoResponseText => 'AI 服务没有返回文本。';

  @override
  String get localAiConnectionFailed => '无法连接 AI 服务，或请求已超时。';

  @override
  String get localAiTestPurpose => '测试 OmniStore 的本地安全 AI 连接';

  @override
  String get localAiInvalidEndpoint => 'AI 服务地址无效。';

  @override
  String get localAiOllamaLoopbackRequired => 'Ollama 地址必须使用本机 HTTP(S) 回环地址。';

  @override
  String get localAiHttpsRequired => '云端 AI 服务必须使用 HTTPS。';

  @override
  String get localAiPrivateEndpointBlocked =>
      '兼容 API 不能指向本机或私有网络。请使用 Ollama 运行本机模型。';

  @override
  String get localAiOllama => 'Ollama（本机）';

  @override
  String get localAiApiKeyRejected => 'AI 服务拒绝了 API 密钥。';

  @override
  String get localAiModelOrEndpointNotFound => '找不到请求的 AI 模型或服务地址。';

  @override
  String get localAiRateLimited => 'AI 服务额度不足或请求过于频繁。';

  @override
  String get localAiUnavailable => 'AI 服务暂时不可用。';

  @override
  String localAiRequestRejected(int status) {
    return 'AI 服务拒绝了请求（HTTP $status）。';
  }

  @override
  String get aiTestService => '服务';

  @override
  String get aiTestConnected => '已连接';

  @override
  String get aiTestUnavailable => '不可用';

  @override
  String get aiTestReady => '已就绪';

  @override
  String get aiTestNotReady => '未就绪';

  @override
  String get aiTestLatency => '延迟';

  @override
  String featuredAppSemantics(String name) {
    return '精选应用：$name';
  }
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
  String get hotApps => '熱門應用程式';

  @override
  String get explore => '探索';

  @override
  String get search => '搜尋';

  @override
  String get settings => '設定';

  @override
  String get downloads => '工作與更新';

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
  String get source => '軟體源';

  @override
  String get variant => '分發版本';

  @override
  String get version => '版本';

  @override
  String get ready => '已安裝';

  @override
  String resultsFound(int count) {
    return '$count 個結果';
  }

  @override
  String get noResults => '未找到相關結果';

  @override
  String get searching => '搜尋中...';

  @override
  String get activity => '任務動態';

  @override
  String get category => '分類';

  @override
  String get packageManager => '套件管理員';

  @override
  String get pacmanOfficial => 'Pacman（官方軟體源）';

  @override
  String get pacmanBrowsingNoAuthorization =>
      '瀏覽、搜尋、查看詳細資料和檢查 Pacman 更新均不需要帳號或管理員認證；只有變更系統時才會要求授權。';

  @override
  String get aurUser => 'AUR（使用者軟體源）';

  @override
  String get flatpak => 'Flatpak';

  @override
  String get appImage => 'AppImage';

  @override
  String get sourcePriority => '軟體源優先級（拖曳排序）';

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
  String get loggingLevel => '日誌級別';

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
  String get confirm => '確認';

  @override
  String get terminalOutput => '終端輸出';

  @override
  String get waitingForOutput => '等待終端輸出...';

  @override
  String get screenshots => '應用程式截圖';

  @override
  String get developer => '開發者';

  @override
  String get license => '授權條款';

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
  String get catUtility => '公用程式';

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
    return 'OmniStore：發現 $count 個可用更新';
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
  String get noActiveTasks => '暫無進行中的任務';

  @override
  String get currentTask => '目前任務';

  @override
  String get viewLogs => '查看日誌';

  @override
  String get allUpdated => '未發現軟體套件更新';

  @override
  String get update => '更新';

  @override
  String updatingSourcePackages(String source) {
    return '正在更新 $source 套件…';
  }

  @override
  String sourceUpdateFailed(String source) {
    return '$source 更新失敗';
  }

  @override
  String get enabledSourcesUpdated => '所有已啟用的軟體源均已更新';

  @override
  String get enableSystemTray => '啟用系統匣';

  @override
  String get systemCleaning => '系統清理';

  @override
  String get system => '系統';

  @override
  String get clean => '清理';

  @override
  String get systemCleaningDesc => '移除孤立套件並清空 Pacman 快取（需要管理員授權）';

  @override
  String get systemCleaningSubtitle => '清理孤立套件與 pacman 快取';

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
    return '已從備份中讀取 $count 個套件。是否開始批次還原？';
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
  String get repositories => '軟體源';

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
  String get aiPromptExplain => 'AI 解析';

  @override
  String get aiPromptRecommend => 'AI 建議';

  @override
  String get aiPromptError => 'AI 分析錯誤';

  @override
  String get aiPickDay => 'AI 今日精選';

  @override
  String get aiPickDaySubtitle => '由 OmniStore AI 提供支援';

  @override
  String get aiCompareTitle => 'AI 版本比較';

  @override
  String get aiHealthTitle => 'AI 系統健康報告';

  @override
  String get aiHealthSubtitle => 'Arch Linux 智慧診斷報告';

  @override
  String get aiCorrection => '您是指？';

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
  String get aiRefineSearch => '使用 AI 優化搜尋';

  @override
  String get aiExplainUpdate => 'AI 解析此更新';

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
  String get welcomeSubtitle => '提供簡單、優雅的 Arch Linux 應用程式管理體驗';

  @override
  String get getStarted => '開始使用';

  @override
  String get skip => '跳過';

  @override
  String get envCheckTitle => '環境檢查';

  @override
  String get envCheckSubtitle => '確保系統已準備就緒';

  @override
  String get envFatalDesc => '系統不是 Arch Linux，核心功能受限。';

  @override
  String get envWarningDesc => '缺少必要組件，將進行自動設定。';

  @override
  String get envOkDesc => '系統狀態良好，一切就緒！';

  @override
  String get fixProblems => '一鍵修復/設定';

  @override
  String get continueAnyway => '仍然繼續';

  @override
  String get sourceConfigTitle => '軟體源設定';

  @override
  String get sourceConfigSubtitle => '選擇 OmniStore 可以搜尋的軟體源';

  @override
  String get enableAur => '啟用 AUR (Arch User Repository)';

  @override
  String get yayDesc => '啟用 AUR 需要安裝 yay 助手。';

  @override
  String get aurWarning => '安全警告：AUR 套件由社群使用者貢獻，請確保信任其來源。';

  @override
  String get bootstrapNote => '瀏覽不需要任何授權；只有設定需要變更系統時才會要求管理員授權。';

  @override
  String get feedbackDesc => '透過 GitHub 回報遇到的問題。';

  @override
  String get aiAssistant => 'AI 助手';

  @override
  String get aiAssistantDesc => '啟用 AI 驅動的搜尋、應用程式解析及錯誤診斷';

  @override
  String get aiProviderDesc => '選擇 AI 模型來源（本地或雲端）';

  @override
  String get aiEndpointHelper => 'Ollama 預設為 http://localhost:11434';

  @override
  String get aiApiKeyHelper => 'Ollama 無需金鑰，OpenAI 需填寫 sk-xxx';

  @override
  String get howToGetApiKey => '如何獲取 API 金鑰？';

  @override
  String get howToGetApiKeyDesc =>
      '1. Ollama (本地)：直接執行，無需金鑰。2. 雲端 (OpenAI)：前往官網建立並填寫金鑰。';

  @override
  String get gotIt => '知道了';

  @override
  String get aiOllamaNote => '確保 Ollama 已在背景執行並啟用了 OLLAMA_ORIGINS=\"*\" 環境變數。';

  @override
  String get enterStore => '進入商店';

  @override
  String get nextStep => '下一步';

  @override
  String get resetCache => '重置快取與歷史記錄';

  @override
  String get resetCacheDesc => '清空搜尋歷史與本地推薦快取';

  @override
  String get resetCacheConfirm => '將清空搜尋歷史與推薦快取。確認繼續？';

  @override
  String get resetting => '正在重置...';

  @override
  String get resetSuccess => '快取與歷史記錄已成功清空';

  @override
  String resetFailed(String error) {
    return '重置失敗：$error';
  }

  @override
  String get ollamaLocal => 'Ollama (本地)';

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
  String get loadError => '無法載入推薦內容，請檢查後端狀態';

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
  String get flatpakBetterDesc => '發現此應用程式有 Flatpak 軟體源，通常更穩定。';

  @override
  String get aiAnalysisPrompt => '發現錯誤日誌，需要 AI 分析嗎？';

  @override
  String get analyzeNow => '立即分析';

  @override
  String get cleanOrphans => '清理孤立套件';

  @override
  String get securityWarning => '安全風險提示';

  @override
  String get aurSecurityDesc =>
      'AUR 是由社群維護的軟體源。由於任何人都可以上傳套件，其中可能包含不安全的程式碼。建議在安裝前仔細檢查 PKGBUILD。';

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
    return '依賴項（$count）';
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
  String get clearHistoryShort => '清空歷史';

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
    return '有 $count 個應用程式可以更新';
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
  String get searchFailedSubtitle => '無法連線至軟體源。請檢查網路連線後重試。';

  @override
  String pluginCapabilities(int count) {
    return '$count 項功能';
  }

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
  String get aurFull => 'AUR（Arch 使用者軟體源）';

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
  String get relatedApps => '相關應用程式';

  @override
  String get activeSources => '已啟用軟體源';

  @override
  String get autoDetect => '自動偵測';

  @override
  String get addCustomSource => '新增自訂軟體源';

  @override
  String get addCustomSourceDesc =>
      '設定自訂 Pacman/Flatpak 倉庫、AppImage 訂閱或 GitHub/Bitu 軟體源';

  @override
  String get pacmanRepoType => 'Pacman 軟體倉庫';

  @override
  String get pacmanRepoSafety =>
      '僅接受 HTTPS 倉庫並強制套件簽章。OmniStore 不會下載簽章金鑰，也不會執行 pacman -Sy；此來源會在下一次完整系統升級時生效。';

  @override
  String get sourceType => '軟體源類型';

  @override
  String get githubRepoType => 'GitHub 倉庫（owner/repo）';

  @override
  String get bituRepoType => 'Bitu / Bitbucket（工作區/倉庫）';

  @override
  String get flatpakRemoteType => 'Flatpak 遠端軟體源';

  @override
  String get appImageFeedType => 'AppImage 訂閱連結';

  @override
  String get sourceName => '軟體源名稱';

  @override
  String get hintCustomAppName => '例如：my-custom-app';

  @override
  String get repoOwnerRepo => '倉庫地址（owner/repo）';

  @override
  String get sourceUrl => '連結';

  @override
  String get hintRepoFormat => '例如：flutter/flutter';

  @override
  String get hintFeedUrl => '例如：https://example.com/feed.json';

  @override
  String get errorNameUrlRequired => '名稱和連結/軟體源地址不能為空';

  @override
  String get addingCustomSource => '正在新增自訂軟體源...';

  @override
  String get sourceAddSuccess => '軟體源新增成功！';

  @override
  String get sourceAddFailed => '新增軟體源失敗。';

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
  String get copiedToClipboard => '已複製到剪貼簿';

  @override
  String get tapToCopy => '點擊複製';

  @override
  String get language => '介面語言';

  @override
  String get languageSubtitle => '重啟應用程式後生效';

  @override
  String get restartTitleBar => '重啟應用程式後標題列設定生效';

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
    return '每隔 $hours 小時自動檢查一次';
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
    return 'Pacman：$pacman MB | Flatpak：$flatpak MB | 自訂：$custom MB';
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
  String get enableSystemdService => '啟用 systemd 背景更新服務';

  @override
  String get enableSystemdServiceDesc => '允許在應用程式關閉時透過註冊 systemd 定時器來靜默檢查更新';

  @override
  String get taskHistory => '任務歷史記錄';

  @override
  String get unknownApp => '未知應用程式';

  @override
  String get taskSuccessMsg => '已成功完成';

  @override
  String failureReason(String message) {
    return '失敗原因：$message';
  }

  @override
  String get noPackagesAvailable => '暫無可用套件';

  @override
  String get noDescription => '暫無說明';

  @override
  String get viewDetails => '查看詳情';

  @override
  String get ok => '確定';

  @override
  String get checkNetwork => '請檢查網路連線並重試';

  @override
  String get githubStoreSubtitle => '直接從 GitHub Releases 發現並下載應用程式';

  @override
  String get searchGithubHint => '搜尋 GitHub 倉庫...';

  @override
  String get recommended => '推薦';

  @override
  String get rankings => '排行榜';

  @override
  String get trending => '熱度榜';

  @override
  String get latestUpdates => '最新更新';

  @override
  String get searchNoResultsSubtitle => '請嘗試其他關鍵字，或啟用更多軟體源';

  @override
  String get pluginsAndSources => '外掛程式與軟體源';

  @override
  String get refreshPlugins => '重新整理外掛程式';

  @override
  String get noPluginsFound => '未找到外掛程式';

  @override
  String get builtin => '內建';

  @override
  String get legacy => '舊版';

  @override
  String get pluginUpdated => '外掛程式已更新';

  @override
  String get pluginUpdateFailed => '外掛程式更新失敗';

  @override
  String get pluginRemoved => '外掛程式已移除';

  @override
  String get pluginRemovalFailed => '外掛程式移除失敗';

  @override
  String get removePlugin => '移除外掛程式';

  @override
  String get managed => '已代管';

  @override
  String get readOnly => '唯讀';

  @override
  String get installationDecisionTitle => '安裝決策助手';

  @override
  String recommendedSource(String source) {
    return '推薦軟體源：$source';
  }

  @override
  String get preflightChecks => '安裝前檢查';

  @override
  String get potentialRisks => '風險提示';

  @override
  String get continueInstallation => '繼續安裝';

  @override
  String get changeRecommendation => '換一個推薦';

  @override
  String get aiPickDisclaimer => '推薦結果僅供參考：基於您的搜尋習慣和當前軟體源設定生成，不會影響您的具體安裝選項。';

  @override
  String get quickStart => '快速開始';

  @override
  String get importListSubtitle => '從清單匯入常用套件';

  @override
  String get emptyTrendingMessage => '暫無熱門資料；網路連線恢復後將自動更新。';

  @override
  String get emptyRecommendationsMessage => '繼續搜尋或安裝應用程式後，此處將顯示個人化建議。';

  @override
  String get aiPickFallbackMessage => '暫時無法產生個人化推薦。可瀏覽編輯精選或稍後重試。';

  @override
  String get meoarchAccount => 'MeoArch 帳戶';

  @override
  String get defaultUser => '使用者';

  @override
  String get signOut => '登出';

  @override
  String get syncStatus => '同步狀態';

  @override
  String get syncStatusSubtitle => '點按備份 OmniStore 應用程式清單';

  @override
  String get manageAccount => '管理帳戶';

  @override
  String get manageAccountSubtitle => '安全性、多因素驗證與階段作業管理';

  @override
  String get signInTitle => '登入 MeoArch';

  @override
  String get signInSubtitle => '跨裝置同步應用程式、設定與最愛';

  @override
  String get email => '電子郵件';

  @override
  String get password => '密碼';

  @override
  String get showPassword => '顯示密碼';

  @override
  String get hidePassword => '隱藏密碼';

  @override
  String get signIn => '登入';

  @override
  String get createAccount => '建立 MeoArch 帳戶';

  @override
  String get orDivider => '或';

  @override
  String get continueWithGoogle => '使用 Google 帳戶繼續';

  @override
  String get continueWithGitHub => '使用 GitHub 帳戶繼續';

  @override
  String get enterEmailAndPassword => '請輸入電子郵件和密碼。';

  @override
  String signInFailed(String message) {
    return '登入失敗：$message';
  }

  @override
  String signInError(String message) {
    return '登入錯誤：$message';
  }

  @override
  String get githubIntegration => 'GitHub 整合';

  @override
  String get configurePat => 'GitHub 存取權杖（選用）';

  @override
  String get patHelperText => '請提供 GitHub Classic PAT 或 Fine-grained 權杖。';

  @override
  String get featuredSubtitle => '由 OmniStore 維護，離線時也始終可見';

  @override
  String get editorPicks => '編輯推薦';

  @override
  String get checkingEnvStatus => '正在檢查環境狀態...';

  @override
  String get envDetailsFailed => '取得環境詳細資訊失敗。';

  @override
  String get bootstrapProgress => '環境設定進度：';

  @override
  String get systemDetails => '系統詳細資訊：';

  @override
  String get aiIntegrationDesc => '開啟智慧整合與輔助功能';

  @override
  String get ollamaLocalOffline => 'Ollama (本地 / 離線)';

  @override
  String get openaiCloud => 'OpenAI API (雲端)';

  @override
  String get testConnection => '測試連線';

  @override
  String get githubSearchFailed => 'GitHub 搜尋失敗';

  @override
  String get githubStoreUnavailable => 'GitHub 商店暫不可用';

  @override
  String get noGithubReposFound => '未找到 GitHub 軟體倉庫';

  @override
  String get pullToRefreshCategory => '下拉重新整理或嘗試其他分類。';

  @override
  String sourceFilterSemantics(String name) {
    return '按軟體源篩選：$name';
  }

  @override
  String get meoChannelTitle => 'Meo 更新通道';

  @override
  String get meoChannelSubtitle => '從目前 pacman 軟體源順序讀取';

  @override
  String get meoChannelBetaNotice =>
      'Beta 通道可優先體驗最新的 Meo 元件。Arch 系統套件仍保持預設軟體源。';

  @override
  String get meoChannelStableNotice => 'Stable 通道接收經過完整測試的 MeoArch 穩定發行版本。';

  @override
  String repoPriority(String repos) {
    return '軟體源優先級：$repos';
  }

  @override
  String get betaWarningPanel =>
      'Beta 為手動開啟選項，不建議在生產環境或關鍵系統中使用。Stable 仍為後備軟體源。';

  @override
  String downgradeReviewPending(int count) {
    return '已設定 Stable 通道，但仍有 $count 個 Meo 套件降級項需要審查。';
  }

  @override
  String get reviewDowngrades => '審查降級項';

  @override
  String get switchToStable => '切換至穩定版';

  @override
  String downgradeNotice(String packages) {
    return '以下官方 Meo 套件需要降級至穩定版本。Arch 及第三方套件不會被降級。\n\n$packages';
  }

  @override
  String get channelStable => '穩定版';

  @override
  String get channelBeta => 'Beta 版';

  @override
  String get download => '下載';

  @override
  String get systemAiProviderLabel => '系統 AI 連線（KWallet / 建議）';

  @override
  String get systemAiSharedConnectionLabel => '系統共用連線';

  @override
  String get systemAiConnectionHelper =>
      '金鑰由 Meo Account 從 KWallet 讀取，OmniStore 無法讀取明文。';

  @override
  String get systemAiLoadingTitle => '正在讀取系統 AI 連線';

  @override
  String get systemAiMetadataOnly => '只讀取名稱、端點與預設模型，不讀取金鑰。';

  @override
  String get systemAiLoadErrorTitle => '無法讀取系統 AI 連線';

  @override
  String get systemAiSelectLabel => '此裝置的 AI 連線';

  @override
  String get meoSettingsOpenFailed => '無法開啟 Meo Settings。';

  @override
  String get manageInMeoSettings => '在 Meo Settings 中管理';

  @override
  String get systemAiNoConnections => '尚未設定系統 AI 連線；請先在 Meo Settings 中新增。';

  @override
  String get systemAiLoadFailed =>
      '無法讀取系統 AI 連線；請在 Meo Settings 的「帳號與安全性」中檢查設定。';

  @override
  String get systemAiInvalidCatalog => '系統 AI 服務傳回無效的模型目錄。';

  @override
  String get systemAiInvalidConsent => '系統 AI 服務未傳回有效的授權摘要。';

  @override
  String get systemAiConsentExpired => '系統 AI 授權摘要無效或已過期。';

  @override
  String get systemAiInvalidResponse => '系統 AI 服務未傳回有效文字。';

  @override
  String get systemAiUnsupported => '目前平台不支援系統 AI 服務。';

  @override
  String get systemAiOperationFailed => '系統 AI 操作失敗。';

  @override
  String get systemAiTimeout => '系統 AI 操作逾時。';

  @override
  String get systemAiUnavailable => '無法連線到 Meo Account 系統 AI 服務。';

  @override
  String get systemAiTestPurpose => '測試 OmniStore 的系統 AI 連線';

  @override
  String get aiConsentCancelled => '你已取消這次 AI 請求。';

  @override
  String get chooseSystemAiConnection => '請先在 OmniStore 設定中選擇系統 AI 連線。';

  @override
  String get chooseAccountAiConnection => '請先在 OmniStore 設定中選擇帳號 AI 連線。';

  @override
  String get aiConfigUnavailable => 'AI 設定無法使用。';

  @override
  String get aiNotEnabled => 'AI 輔助尚未啟用。';

  @override
  String get aiAccountProviderHint =>
      'Account 只代為呼叫你已儲存的連線；API 金鑰不會傳給 OmniStore。';

  @override
  String get aiSystemProviderHint =>
      '由 Meo Account 從 KWallet 呼叫；OmniStore 只會看到連線資訊與最終結果。';

  @override
  String get aiOllamaProviderHint => 'Ollama 僅連線本機服務；不需要 API 金鑰。';

  @override
  String get aiCompatibleProviderHint => '僅使用你信任的 HTTPS 相容端點；金鑰仍保存在本機安全憑證庫。';

  @override
  String get aiLocalKeyProviderHint =>
      '此服務商的金鑰獨立保存在 Secret Service/KWallet，無法讀回明文。';

  @override
  String get meoAccountOpenFailed => '無法開啟 Meo Account。';

  @override
  String get secureCredentialWriteFailed => '無法寫入系統安全憑證庫。';

  @override
  String get modelsNoneFound => '服務正在執行，但沒有發現已安裝或可用的模型。';

  @override
  String get modelsAutofilled => '已發現並自動填入模型。';

  @override
  String get modelsFoundChoose => '已發現模型；請選擇後再測試，OmniStore 不會依名稱猜測能力。';

  @override
  String get apiKeyRequired => '請先填寫新的 API 金鑰。';

  @override
  String get secureCredentialSaved => 'API 金鑰已寫入系統安全憑證庫。';

  @override
  String get localApiKeyDeleted => '本機 API 金鑰已刪除。';

  @override
  String get secureCredentialUnavailable => '無法存取系統安全憑證庫。';

  @override
  String get signInMeoAccount => '登入 Meo Account';

  @override
  String get signInMeoAccountDetail =>
      '登入後即可選擇帳號中加密儲存的 AI 連線；API 金鑰不會傳給 OmniStore。';

  @override
  String get accountAiLoading => '正在讀取帳號 AI 連線';

  @override
  String get accountAiMetadataOnly => '只讀取名稱、服務商與金鑰遮罩。';

  @override
  String get accountAiLoadError => '無法讀取帳號 AI 連線';

  @override
  String get accountAiNone => '帳號中尚無 AI 連線';

  @override
  String get accountAiNoneDetail => '前往 Account 安全儲存你的 API 金鑰，然後回到這裡重新整理。';

  @override
  String get connect => '前往連線';

  @override
  String get accountAiSelectLabel => '帳號 AI 連線';

  @override
  String get accountAiConnectionHelper =>
      '金鑰只在 Account Edge broker 中解密，OmniStore 無法讀取。';

  @override
  String get manageAiConnections => '管理 AI 連線';

  @override
  String get aiPerRequestConsentDetail =>
      '每次傳送前，OmniStore 都會顯示服務商、模型、用途、資料類別、完整內容與請求指紋，並要求僅同意這一次。';

  @override
  String get aiEnabledConsentDesc => '預設關閉；啟用後每次傳送仍需個別確認。';

  @override
  String providerLocalSecureKey(String provider) {
    return '$provider（本機安全金鑰）';
  }

  @override
  String get providerCompatibleHttps => 'OpenAI Compatible（自訂 HTTPS）';

  @override
  String get providerMeoAccount => 'Meo Account';

  @override
  String get ollamaEndpointSafety => '預設連線本機 Ollama；請保留回環位址以避免意外存取區域網路服務。';

  @override
  String get compatibleEndpointSafety => '僅填寫你信任的 HTTPS 相容端點，不包含金鑰或查詢參數。';

  @override
  String get accountModelOverride => '帳號模型';

  @override
  String get accountModelDefaultHelper => '留空會使用所選 Account AI 連線的預設模型。';

  @override
  String get modelReviewHelper => '實際模型會在每次傳送前再次顯示供你確認。';

  @override
  String get detectLocalModels => '偵測本機模型並自動填入';

  @override
  String get readModelCatalog => '讀取模型目錄';

  @override
  String get installOllamaWithOmniStore => '透過 OmniStore 安裝 Ollama';

  @override
  String get chooseDiscoveredModel => '選擇已發現的模型';

  @override
  String get localKeyStored => '目前服務商已有獨立安全金鑰';

  @override
  String get localKeyNotStored => '目前服務商尚未儲存 API 金鑰';

  @override
  String get localKeysHelper =>
      '每個服務商分別保存在 Secret Service/KWallet；只能取代或刪除，不能讀回明文。';

  @override
  String get newApiKeyLabel => '新的 API 金鑰（寫入後清空）';

  @override
  String get newApiKeyHelper => '僅填寫要取代的新金鑰；儲存後不能讀取或複製舊金鑰。';

  @override
  String get hideInput => '隱藏輸入';

  @override
  String get showInput => '顯示輸入';

  @override
  String get saveOrReplace => '安全儲存 / 取代';

  @override
  String get deleteLocalKey => '刪除本機金鑰';

  @override
  String get temperatureHelper => '0–2；較低數值通常更穩定，範圍外不會儲存。';

  @override
  String get aiTestScopeHelper => '測試只驗證目前連線，不會變更「啟用 AI 輔助」開關；實際傳送仍需單次確認。';

  @override
  String get meoUpdateChannel => 'Meo 更新通道';

  @override
  String get meoUpdateChannelSubtitle => '依目前生效的 Pacman 軟體來源讀取';

  @override
  String get meoChannelChecking => '正在檢查更新通道…';

  @override
  String get meoChannelStable => '穩定版';

  @override
  String get meoChannelBeta => '測試版';

  @override
  String get meoChannelBetaSummary => '搶先使用較新的 Meo 元件；Arch 系統套件仍使用其正常軟體來源。';

  @override
  String get meoChannelStableSummary => '使用經過完整測試的 MeoArch 發行列車。';

  @override
  String meoChannelRepositoryPriority(String repositories) {
    return '軟體來源優先順序：$repositories';
  }

  @override
  String meoChannelDowngradePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已選擇穩定版，但仍有 $count 個 Meo 套件降級需要你確認。',
      one: '已選擇穩定版，但仍有 1 個 Meo 套件降級需要你確認。',
    );
    return '$_temp0';
  }

  @override
  String get meoChannelReviewDowngrades => '查看降級項目';

  @override
  String get meoChannelSwitchToStable => '切換至穩定版';

  @override
  String get meoChannelRollbackPreviewInvalid => '這份穩定版回退預覽已失效。請重新整理後再次查看。';

  @override
  String meoChannelDowngradeDialog(String packages) {
    return '以下官方 Meo 套件將切換至穩定版。Arch 或第三方套件不會降級。\\n\\n$packages';
  }

  @override
  String get aiConsentTitle => '確認這次 AI 請求';

  @override
  String get aiConsentIntro => '請先查看以下內容。你的確認只適用於這次請求及其指紋。';

  @override
  String get aiConsentProvider => '服務商';

  @override
  String get aiConsentDestination => '傳送至';

  @override
  String get aiConsentModel => '模型';

  @override
  String get aiConsentPurpose => '用途';

  @override
  String get aiConsentDataCategories => '將傳送的資料';

  @override
  String get aiConsentCharacters => '字元數';

  @override
  String get aiConsentFingerprint => '請求指紋';

  @override
  String get aiConsentReviewContent => '查看將傳送的內容';

  @override
  String get aiConsentSystemInstruction => '系統指令';

  @override
  String get aiConsentUserContent => '你的內容';

  @override
  String aiConsentConfirmWithProvider(String provider) {
    return '我確認以上內容將傳送給 $provider。';
  }

  @override
  String get aiConsentKeyNotExposed => 'API 金鑰不屬於這段提示內容，也不會在這裡顯示。';

  @override
  String get aiConsentDeny => '暫不傳送';

  @override
  String get aiConsentAllowOnce => '確認並傳送一次';

  @override
  String get aiConsentCategoryAppName => '應用程式名稱';

  @override
  String get aiConsentCategoryAppDescription => '應用程式說明';

  @override
  String get aiConsentCategoryVersionMetadata => '版本資訊';

  @override
  String get aiConsentCategoryPackageSource => '軟體來源';

  @override
  String get aiConsentCategoryPackageVariants => '可選安裝版本';

  @override
  String get aiConsentCategoryPreferenceRequest => '偏好請求';

  @override
  String get aiConsentCategorySearchQuery => '搜尋關鍵字';

  @override
  String get aiConsentCategorySystemEnvironment => '系統環境摘要';

  @override
  String get aiConsentCategoryErrorLog => '錯誤日誌';

  @override
  String get aiConsentCategoryRecommendationRequest => '推薦需求';

  @override
  String get aiConsentCategoryConnectionTest => '連線測試資料';

  @override
  String get githubLoadErrorDetail => '無法載入 GitHub 儲存庫。請檢查網路後再試一次。';

  @override
  String get githubSearchErrorDetail => '無法搜尋 GitHub 儲存庫。請檢查網路後再試一次。';

  @override
  String get flatpakLoadErrorDetail =>
      '無法載入 Flatpak 應用程式。請檢查 Flathub 與網路連線後再試一次。';

  @override
  String appCardSemantics(String name) {
    return '應用程式：$name';
  }

  @override
  String get diskSize => '磁碟空間占用';

  @override
  String diskSizeWithConfidence(String confidence) {
    return '磁碟空間占用（$confidence）';
  }

  @override
  String get accountAiSignInRequired => '請先登入 Meo Account，再使用帳號 AI。';

  @override
  String get accountAiNoDefaultModel => '此 AI 連線沒有預設模型。請先在設定中選擇模型。';

  @override
  String get accountAiInvalidConsent => '帳號 AI 服務未傳回有效的授權摘要。';

  @override
  String get accountAiConsentExpired => 'AI 授權摘要無效或已過期。';

  @override
  String get accountAiInvalidResponse => 'AI 服務未傳回有效內容。';

  @override
  String get accountAiTestPurpose => '測試 OmniStore 的帳號 AI 連線';

  @override
  String get accountAiInvalidDestination => '帳號 AI 連線的目標位址無效。';

  @override
  String get accountAiConnectionNotFound => '所選 AI 連線無法使用。請在設定中重新選擇。';

  @override
  String get accountAiInvalidData => '帳號 AI 服務傳回無效資料。';

  @override
  String get accountAiUnavailable => '帳號 AI 服務暫時無法使用。';

  @override
  String get accountAiRequestDenied => '帳號 AI 請求遭到拒絕。請重新登入後再試。';

  @override
  String get accountAiConnectionFailed => '無法連線到帳號 AI 服務。';

  @override
  String get localAiUnsupportedModelDiscovery => '此連線不支援本機模型探索。';

  @override
  String get localAiCredentialStoreUnavailable => '無法開啟安全憑證庫。請解鎖 KWallet 後再試。';

  @override
  String get localAiApiKeyRequired => '請先為目前服務商安全儲存 API 金鑰。';

  @override
  String get localAiCatalogTooLarge => '模型目錄回應過大。';

  @override
  String get localAiInvalidCatalog => '模型目錄傳回無效資料。';

  @override
  String get localAiCatalogUnavailable => '無法讀取模型目錄。請確認服務正在執行。';

  @override
  String get localAiUnsupportedConnection => '不支援這種本機 AI 連線類型。';

  @override
  String get localAiInvalidModel => '請輸入有效的模型名稱。';

  @override
  String get localAiInvalidPurpose => 'AI 請求用途無效。';

  @override
  String get localAiInvalidInput => 'AI 輸入為空或過大。';

  @override
  String get localAiInvalidDataCategories => 'AI 資料類別無效。';

  @override
  String get localAiApiKeyInvalid => '安全憑證庫中沒有此服務商的有效 API 金鑰。';

  @override
  String get localAiDestinationChanged => 'AI 目的地在確認後發生變化，請求已遭攔截。';

  @override
  String get localAiResponseTooLarge => 'AI 服務回應過大。';

  @override
  String get localAiInvalidResponse => 'AI 服務傳回無效資料。';

  @override
  String get localAiNoResponseText => 'AI 服務未傳回文字。';

  @override
  String get localAiConnectionFailed => '無法連線到 AI 服務，或請求已逾時。';

  @override
  String get localAiTestPurpose => '測試 OmniStore 的本機安全 AI 連線';

  @override
  String get localAiInvalidEndpoint => 'AI 服務位址無效。';

  @override
  String get localAiOllamaLoopbackRequired => 'Ollama 位址必須使用本機 HTTP(S) 回送位址。';

  @override
  String get localAiHttpsRequired => '雲端 AI 服務必須使用 HTTPS。';

  @override
  String get localAiPrivateEndpointBlocked =>
      '相容 API 不能指向本機或私有網路。請使用 Ollama 執行本機模型。';

  @override
  String get localAiOllama => 'Ollama（本機）';

  @override
  String get localAiApiKeyRejected => 'AI 服務拒絕了 API 金鑰。';

  @override
  String get localAiModelOrEndpointNotFound => '找不到請求的 AI 模型或服務位址。';

  @override
  String get localAiRateLimited => 'AI 服務額度不足或請求過於頻繁。';

  @override
  String get localAiUnavailable => 'AI 服務暫時無法使用。';

  @override
  String localAiRequestRejected(int status) {
    return 'AI 服務拒絕了請求（HTTP $status）。';
  }

  @override
  String get aiTestService => '服務';

  @override
  String get aiTestConnected => '已連線';

  @override
  String get aiTestUnavailable => '無法使用';

  @override
  String get aiTestReady => '已就緒';

  @override
  String get aiTestNotReady => '未就緒';

  @override
  String get aiTestLatency => '延遲';

  @override
  String featuredAppSemantics(String name) {
    return '精選應用程式：$name';
  }
}
