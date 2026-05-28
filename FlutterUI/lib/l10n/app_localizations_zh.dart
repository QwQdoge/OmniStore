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
  String get launch => '启动程序';

  @override
  String get about => '关于此软件';

  @override
  String get details => '详细参数';

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
  String get searching => '正在寻找...';

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
  String get screenshots => '软件截图';

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
  String get catUtility => '工具配件';

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
  String get maintenance => '维护与操作';

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
  String get taskCompleted => '任务执行完成';

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
  String get launch => '啟動程式';

  @override
  String get about => '關於此軟體';

  @override
  String get details => '詳細參數';

  @override
  String get source => '來源';

  @override
  String get variant => '變體';

  @override
  String get version => '版本';

  @override
  String get ready => '已就緒';

  @override
  String resultsFound(int count) {
    return '$count 個結果';
  }

  @override
  String get noResults => '未找到相關應用';

  @override
  String get searching => '正在尋找...';

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
  String get sourcePriority => '結果源優先級 (拖動排序)';

  @override
  String get maxResults => '最大顯示結果數';

  @override
  String get appearance => '外觀模式';

  @override
  String get themeColor => '主題色種子';

  @override
  String get followSystem => '跟隨系統';

  @override
  String get lightMode => '淺色模式';

  @override
  String get darkMode => '深色模式';

  @override
  String get loggingLevel => '日誌記錄等級';

  @override
  String get saveAndApply => '儲存並應用';

  @override
  String get configSaved => '配置已儲存，部分設定重啟生效';

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
  String get waitingForOutput => '正在等待輸出...';

  @override
  String get screenshots => '軟體截圖';

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
  String get updates => '更新';

  @override
  String get upToDate => '所有應用程式已是最新';

  @override
  String get checkUpdates => '檢查更新';

  @override
  String foundUpdates(int count) {
    return '發現 $count 個更新';
  }

  @override
  String get updateAll => '全部更新';

  @override
  String get notifications => '通知設定';

  @override
  String get enableNotifications => '啟用通知';

  @override
  String get progressNotifications => '進度通知';

  @override
  String get completionNotifications => '完成通知';

  @override
  String get closeToTray => '關閉時隱藏到系統托盤';

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
  String get trayTooltipUpToDate => 'OmniStore: 應用程式已是最新';

  @override
  String get updateReminders => '更新提醒';

  @override
  String get maintenance => '維護與操作';

  @override
  String get updateAllPackages => '更新所有應用程式';

  @override
  String get includeAurUpdates => '更新所有時包含 AUR';

  @override
  String get resetOnboarding => '重置引導 (歡迎頁面)';

  @override
  String get resetOnboardingConfirm => '確定要重置引導嗎？下次啟動將重新顯示歡迎頁面。';

  @override
  String get checkInterval => '自動檢查更新間隔 (小時)';

  @override
  String get remindMeOfUpdates => '提醒我有可用更新';

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
  String get taskCompleted => '任務執行完成';

  @override
  String get searchInstalledHint => '搜尋已安裝的應用程式...';

  @override
  String get refresh => '重新整理';

  @override
  String get noActiveTasks => '暫无進行中的任務';

  @override
  String get currentTask => '目前任務';

  @override
  String get viewLogs => '查看日誌';

  @override
  String get allUpdated => '所有應用程式已是最新';

  @override
  String get update => '更新';
}
