// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get searchHint => 'Search apps, games, tools...';

  @override
  String get featured => 'Featured';

  @override
  String get forYou => 'For You';

  @override
  String get essentialTools => 'Essential Tools';

  @override
  String get hotApps => 'Hot Apps';

  @override
  String get explore => 'Explore';

  @override
  String get search => 'Search';

  @override
  String get settings => 'Settings';

  @override
  String get downloads => 'Downloads';

  @override
  String get help => 'Help';

  @override
  String get userAccount => 'User Account';

  @override
  String get install => 'Install';

  @override
  String get open => 'Open';

  @override
  String get uninstall => 'Uninstall';

  @override
  String get launch => 'Launch';

  @override
  String get about => 'About';

  @override
  String get details => 'Details';

  @override
  String get source => 'Source';

  @override
  String get variant => 'Variant';

  @override
  String get version => 'Version';

  @override
  String get ready => 'Ready';

  @override
  String resultsFound(int count) {
    return '$count results';
  }

  @override
  String get noResults => 'No results found';

  @override
  String get searching => 'Searching...';

  @override
  String get activity => 'Activity';

  @override
  String get category => 'Category';

  @override
  String get packageManager => 'Package Manager';

  @override
  String get pacmanOfficial => 'Pacman (Official)';

  @override
  String get aurUser => 'AUR (User)';

  @override
  String get flatpak => 'Flatpak';

  @override
  String get appImage => 'AppImage';

  @override
  String get sourcePriority => 'Source Priority (Drag to reorder)';

  @override
  String get maxResults => 'Max Results';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeColor => 'Theme Color Seed';

  @override
  String get followSystem => 'Follow System';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get loggingLevel => 'Logging Level';

  @override
  String get saveAndApply => 'Save and Apply';

  @override
  String get configSaved => 'Configuration saved';

  @override
  String get configSaveFailed => 'Failed to save configuration';

  @override
  String get confirmUninstall => 'Confirm Uninstall';

  @override
  String get confirmInstall => 'Confirm Install';

  @override
  String confirmActionMsg(String name) {
    return 'Are you sure you want to perform this action on $name?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get terminalOutput => 'Terminal Output';

  @override
  String get waitingForOutput => 'Waiting for output...';

  @override
  String get screenshots => 'Screenshots';

  @override
  String get developer => 'Developer';

  @override
  String get license => 'License';

  @override
  String get success => 'Success';

  @override
  String get failed => 'Failed';

  @override
  String get taskCancelled => 'Task Cancelled';

  @override
  String get catDevelopment => 'Development';

  @override
  String get catMedia => 'Media';

  @override
  String get catInternet => 'Internet';

  @override
  String get catSystem => 'System';

  @override
  String get catOffice => 'Office';

  @override
  String get catGames => 'Games';

  @override
  String get catGraphics => 'Graphics';

  @override
  String get catUtility => 'Utilities';

  @override
  String get systemAndWindow => 'System & Window';

  @override
  String get visitWebsite => 'Visit Website';

  @override
  String get updates => 'Updates';

  @override
  String get upToDate => 'All apps are up to date';

  @override
  String get checkUpdates => 'Check for Updates';

  @override
  String foundUpdates(int count) {
    return 'Found $count updates';
  }

  @override
  String get updateAll => 'Update All';

  @override
  String get notifications => 'Notifications';

  @override
  String get enableNotifications => 'Enable Notifications';

  @override
  String get progressNotifications => 'Progress Notifications';

  @override
  String get completionNotifications => 'Completion Notifications';

  @override
  String get closeToTray => 'Close to system tray';

  @override
  String get useSystemTitleBar => 'Use system title bar';

  @override
  String get showWindow => 'Show Window';

  @override
  String get exit => 'Exit';

  @override
  String trayTooltipUpdates(int count) {
    return 'OmniStore: Found $count updates';
  }

  @override
  String get trayTooltipUpToDate => 'OmniStore: Up to date';

  @override
  String get updateReminders => 'Update Reminders';

  @override
  String get maintenance => 'Maintenance';

  @override
  String get updateAllPackages => 'Update All Packages';

  @override
  String get includeAurUpdates => 'Include AUR in \'Update All\'';

  @override
  String get resetOnboarding => 'Reset Onboarding (Welcome Page)';

  @override
  String get resetOnboardingConfirm =>
      'Are you sure you want to reset onboarding? The welcome page will show on next launch.';

  @override
  String get checkInterval => 'Update Check Interval (Hours)';

  @override
  String get remindMeOfUpdates => 'Remind Me of Updates';

  @override
  String installingApp(String name) {
    return 'Installing $name';
  }

  @override
  String uninstallingApp(String name) {
    return 'Uninstalling $name';
  }

  @override
  String get installSuccessTitle => 'Installation Successful';

  @override
  String get uninstallSuccessTitle => 'Uninstallation Successful';

  @override
  String get installFailedTitle => 'Installation Failed';

  @override
  String get uninstallFailedTitle => 'Uninstallation Failed';

  @override
  String get taskCompleted => 'Task Completed';

  @override
  String get searchInstalledHint => 'Search installed apps...';

  @override
  String get refresh => 'Refresh';

  @override
  String get noActiveTasks => 'No active tasks';

  @override
  String get currentTask => 'Current Task';

  @override
  String get viewLogs => 'View Logs';

  @override
  String get allUpdated => 'All apps are up to date';

  @override
  String get update => 'Update';

  @override
  String get enableSystemTray => 'Enable system tray';

  @override
  String get systemCleaning => 'System Cleaning';

  @override
  String get systemCleaningSubtitle =>
      'Delete orphan packages and clean pacman cache';

  @override
  String get systemCleaningStarted => 'System cleaning task started';

  @override
  String get backupAndExport => 'Backup and Export';

  @override
  String get backupAndExportSubtitle =>
      'Export current installed app list or import from backup';

  @override
  String get export => 'Export';

  @override
  String get import => 'Import';

  @override
  String get selectExportLocation => 'Select export location';

  @override
  String exportSuccess(int count) {
    return 'Export successful: $count packages';
  }

  @override
  String exportFailed(String message) {
    return 'Export failed: $message';
  }

  @override
  String get importBackup => 'Import Backup';

  @override
  String importBackupConfirm(int count) {
    return 'Read $count packages from backup. Start batch recovery?';
  }

  @override
  String get startRecovery => 'Start Recovery';

  @override
  String get mirrorListSaved => 'Mirror list saved';

  @override
  String get addMirror => 'Add Mirror';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get pacmanMirrorManagement => 'Pacman Mirror Management';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get aiSettings => 'AI Assistant Settings';

  @override
  String get aiEnabled => 'Enable AI Assistant';

  @override
  String get aiProvider => 'AI Provider';

  @override
  String get aiEndpoint => 'API Endpoint';

  @override
  String get aiModel => 'Model Name';

  @override
  String get aiApiKey => 'API Key';

  @override
  String get aiProxy => 'Network Proxy (Optional)';

  @override
  String get aiTemperature => 'Temperature (Creativity)';

  @override
  String get aiMaxTokens => 'Max Response Tokens';

  @override
  String get aiTestButton => 'Test AI Connection';

  @override
  String get aiTestSuccess => 'AI connection successful!';

  @override
  String aiTestFailed(String error) {
    return 'AI connection failed: $error';
  }

  @override
  String get aiPromptExplain => 'Explain with AI';

  @override
  String get aiPromptRecommend => 'Ask AI for Recommendation';

  @override
  String get aiPromptError => 'Analyze Error with AI';

  @override
  String get aiPickDay => 'AI Pick of the Day';

  @override
  String get aiPickDaySubtitle => 'Powered by OmniStore AI';

  @override
  String get aiCompareTitle => 'AI Variant Comparison';

  @override
  String get aiHealthTitle => 'AI System Health Report';

  @override
  String get aiHealthSubtitle => 'Intelligent diagnostic for your Arch Linux';

  @override
  String get aiCorrection => 'Did you mean?';

  @override
  String get aiThinking => 'AI is thinking...';

  @override
  String get magicSearch => 'Magic Search';
}
