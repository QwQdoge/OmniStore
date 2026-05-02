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
  String get featured => '为你推荐';

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
  String trayTooltipUpdates(Object count) {
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
}
