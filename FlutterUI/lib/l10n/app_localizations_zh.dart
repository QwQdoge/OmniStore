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
  String get featured => '精选推荐';

  @override
  String get forYou => '为您推荐';

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
  String get variant => '变体';

  @override
  String get version => '版本';

  @override
  String get ready => '已就绪';

  @override
  String resultsFound(int count) {
    return '$count 个结果';
  }

  @override
  String get noResults => '未找到相关应用';

  @override
  String get searching => '正在搜索...';

  @override
  String get activity => '动态';

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
  String get sourcePriority => '结果源优先级 (拖动排序)';

  @override
  String get maxResults => '最大显示结果数';

  @override
  String get appearance => '外观模式';

  @override
  String get themeColor => '主题色种子';

  @override
  String get followSystem => '跟随系统';

  @override
  String get lightMode => '浅色模式';

  @override
  String get darkMode => '深色模式';

  @override
  String get loggingLevel => '日志记录等级';

  @override
  String get saveAndApply => '保存并应用';

  @override
  String get configSaved => '配置已保存，部分设置重启生效';

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
  String get confirm => '确定';

  @override
  String get terminalOutput => '终端输出';

  @override
  String get waitingForOutput => '正在等待输出...';

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
  String get upToDate => '所有应用已是最新';

  @override
  String get checkUpdates => '检查更新';

  @override
  String foundUpdates(int count) {
    return '发现 $count 个更新';
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
    return 'OmniStore: 发现 $count 个更新';
  }

  @override
  String get trayTooltipUpToDate => 'OmniStore: 应用已是最新';

  @override
  String get updateReminders => '更新提醒';

  @override
  String get maintenance => '维护';

  @override
  String get updateAllPackages => '更新所有应用';

  @override
  String get includeAurUpdates => '更新所有时包含 AUR';

  @override
  String get resetOnboarding => '重置引导 (欢迎页面)';

  @override
  String get resetOnboardingConfirm => '确定要重置引导吗？下次启动将重新显示欢迎页面。';

  @override
  String get checkInterval => '自动检查更新间隔 (小时)';

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
  String get allUpdated => '所有应用已是最新';

  @override
  String get update => '更新';

  @override
  String get enableSystemTray => '启用系统托盘';

  @override
  String get systemCleaning => '系统清理';

  @override
  String get systemCleaningSubtitle => '删除孤立软件包并清理 pacman 缓存';

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
    return '导出成功: $count个软件包';
  }

  @override
  String exportFailed(String message) {
    return '导出失败: $message';
  }

  @override
  String get importBackup => '导入备份';

  @override
  String importBackupConfirm(int count) {
    return '已从备份中读取 $count 个软件包。是否开始批量恢复？';
  }

  @override
  String get startRecovery => '开始恢复';

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
  String get aiSettings => 'AI 助手设置';

  @override
  String get aiEnabled => '启用 AI 助手';

  @override
  String get aiProvider => 'AI 服务商';

  @override
  String get aiEndpoint => 'API 接口地址';

  @override
  String get aiModel => '模型名称';

  @override
  String get aiApiKey => 'API 密钥 (Key)';

  @override
  String get aiProxy => '网络代理 (可选)';

  @override
  String get aiTemperature => '温度 (创意度)';

  @override
  String get aiMaxTokens => '最大响应长度';

  @override
  String get aiTestButton => '测试 AI 连接';

  @override
  String get aiTestSuccess => 'AI 连接成功！';

  @override
  String aiTestFailed(String error) {
    return 'AI 连接失败: $error';
  }

  @override
  String get aiPromptExplain => '使用 AI 解释';

  @override
  String get aiPromptRecommend => '咨询 AI 推荐';

  @override
  String get aiPromptError => 'AI 分析错误';

  @override
  String get aiPickDay => 'AI 每日推荐';

  @override
  String get aiPickDaySubtitle => '由 OmniStore AI 强力驱动';

  @override
  String get aiCompareTitle => 'AI 版本对比';

  @override
  String get aiHealthTitle => 'AI 系统健康报告';

  @override
  String get aiHealthSubtitle => '为您的 Arch Linux 进行智能诊断';

  @override
  String get aiCorrection => '您是不是要找？';

  @override
  String get aiThinking => 'AI 正在思考中...';

  @override
  String get magicSearch => '魔法搜索';

  @override
  String get aiChangelogTitle => 'AI 更新内容总结';

  @override
  String get aiCliTitle => 'AI 终端命令生成';

  @override
  String get aiConflictTitle => 'AI 冲突检测';

  @override
  String get aiCopyCommand => '复制命令';

  @override
  String get aiCommandCopied => '命令已复制到剪贴板';

  @override
  String get aiRefineSearch => '使用 AI 优化搜索';

  @override
  String get aiExplainUpdate => '解释此更新';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get searchHint => '搜尋應用程式、遊戲、工具...';

  @override
  String get featured => '精選推薦';

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
  String get variant => '變體';

  @override
  String get version => '版本';

  @override
  String get ready => '就緒';

  @override
  String resultsFound(int count) {
    return '$count 個結果';
  }

  @override
  String get noResults => '未找到結果';

  @override
  String get searching => '搜尋中...';

  @override
  String get activity => '動態';

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
  String get appearance => '外觀';

  @override
  String get themeColor => '主題色';

  @override
  String get followSystem => '跟隨系統';

  @override
  String get lightMode => '淺色模式';

  @override
  String get darkMode => '深色模式';

  @override
  String get loggingLevel => '日誌等級';

  @override
  String get saveAndApply => '儲存並套用';

  @override
  String get configSaved => '配置已儲存';

  @override
  String get configSaveFailed => '儲存配置失敗';

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
  String get waitingForOutput => '等待輸出中...';

  @override
  String get screenshots => '截圖';

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
  String get upToDate => '已是最新';

  @override
  String get checkUpdates => '檢查更新';

  @override
  String foundUpdates(int count) {
    return '發現 $count 個更新';
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
  String get closeToTray => '關閉時隱藏至系統托盤';

  @override
  String get useSystemTitleBar => '使用系統標題列';

  @override
  String get showWindow => '顯示視窗';

  @override
  String get exit => '退出';

  @override
  String trayTooltipUpdates(int count) {
    return 'OmniStore: 發現 $count 個更新';
  }

  @override
  String get trayTooltipUpToDate => 'OmniStore: 已是最新';

  @override
  String get updateReminders => '更新提醒';

  @override
  String get maintenance => '維護';

  @override
  String get updateAllPackages => '更新所有套件';

  @override
  String get includeAurUpdates => '全部更新時包含 AUR';

  @override
  String get resetOnboarding => '重置引導';

  @override
  String get resetOnboardingConfirm => '確定要重置引導嗎？';

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
  String get allUpdated => '所有應用程式已是最新';

  @override
  String get update => '更新';

  @override
  String get enableSystemTray => '啟用系統托盤';

  @override
  String get systemCleaning => '系統清理';

  @override
  String get systemCleaningSubtitle => '刪除孤立套件並清理 pacman 快取';

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
    return '匯出成功: $count個套件';
  }

  @override
  String exportFailed(String message) {
    return '匯出失敗: $message';
  }

  @override
  String get importBackup => '匯入備份';

  @override
  String importBackupConfirm(int count) {
    return '已從備份中讀取 $count 個套件。是否開始批量恢復？';
  }

  @override
  String get startRecovery => '開始恢復';

  @override
  String get mirrorListSaved => '鏡像列表已儲存';

  @override
  String get addMirror => '添加鏡像';

  @override
  String get serverUrl => '伺服器 URL';

  @override
  String get pacmanMirrorManagement => 'Pacman 鏡像管理';

  @override
  String get save => '儲存';

  @override
  String get add => '添加';

  @override
  String get aiSettings => 'AI 助手設定';

  @override
  String get aiEnabled => '啟用 AI 助手';

  @override
  String get aiProvider => 'AI 服務提供者';

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
  String get aiPromptExplain => '使用 AI 說明';

  @override
  String get aiPromptRecommend => '詢問 AI 推薦';

  @override
  String get aiPromptError => '使用 AI 分析錯誤';

  @override
  String get aiPickDay => 'AI 今日精選';

  @override
  String get aiPickDaySubtitle => '由 OmniStore AI 提供支援';

  @override
  String get aiCompareTitle => 'AI 版本比較';

  @override
  String get aiHealthTitle => 'AI 系統健康報告';

  @override
  String get aiHealthSubtitle => '針對您的 Arch Linux 的智慧診斷';

  @override
  String get aiCorrection => '您是指？';

  @override
  String get aiThinking => 'AI 正在思考中...';

  @override
  String get magicSearch => '魔法搜尋';

  @override
  String get aiChangelogTitle => 'AI 更新摘要';

  @override
  String get aiCliTitle => 'AI 命令產生器';

  @override
  String get aiConflictTitle => 'AI 衝突偵測';

  @override
  String get aiCopyCommand => '複製命令';

  @override
  String get aiCommandCopied => '命令已複製到剪貼簿';

  @override
  String get aiRefineSearch => '使用 AI 精煉搜尋';

  @override
  String get aiExplainUpdate => '說明此更新';
}
