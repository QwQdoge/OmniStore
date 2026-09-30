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
  String get downloads => 'Activity & Updates';

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
  String get variant => 'Variants';

  @override
  String get version => 'Version';

  @override
  String get ready => 'Installed';

  @override
  String resultsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
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
  String get pacmanBrowsingNoAuthorization =>
      'Browsing, searching, viewing details, and checking Pacman updates never require account or administrator authorization. Authorization is requested only when the system is changed.';

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
  String get configSaved =>
      'Configuration saved, some changes will take effect after restart';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $count updates',
      one: 'Found 1 update',
    );
    return '$_temp0';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'OmniStore: Found $count updates',
      one: 'OmniStore: Found 1 update',
    );
    return '$_temp0';
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
  String get noActiveTasks => 'No active or completed tasks';

  @override
  String get currentTask => 'Current Task';

  @override
  String get viewLogs => 'View Logs';

  @override
  String get allUpdated => 'No package updates found';

  @override
  String get update => 'Update';

  @override
  String updatingSourcePackages(String source) {
    return 'Updating $source packages…';
  }

  @override
  String sourceUpdateFailed(String source) {
    return '$source update failed';
  }

  @override
  String get enabledSourcesUpdated =>
      'All enabled package sources are up to date';

  @override
  String get enableSystemTray => 'Enable system tray';

  @override
  String get systemCleaning => 'System Cleaning';

  @override
  String get system => 'System';

  @override
  String get clean => 'Clean';

  @override
  String get systemCleaningDesc =>
      'Remove orphan packages and clear the Pacman cache (administrator authorization required)';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Export successful: $count packages',
      one: 'Export successful: 1 package',
    );
    return '$_temp0';
  }

  @override
  String exportFailed(String message) {
    return 'Export failed: $message';
  }

  @override
  String get importBackup => 'Import Backup';

  @override
  String importBackupConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Read $count packages from backup. Start batch recovery?',
      one: 'Read 1 package from backup. Start recovery?',
    );
    return '$_temp0';
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
  String get general => 'General';

  @override
  String get advanced => 'Advanced';

  @override
  String get repositories => 'Repositories';

  @override
  String get aiSettings => 'AI Assistant Settings';

  @override
  String get aiEnabled => 'Enable AI Assistant';

  @override
  String get aiEnabledDesc =>
      'Enable AI-powered search, app explanation, and error diagnosis.';

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

  @override
  String get aiChangelogTitle => 'AI Update Summary';

  @override
  String get aiCliTitle => 'AI Command Generator';

  @override
  String get aiConflictTitle => 'AI Conflict Detection';

  @override
  String get aiCopyCommand => 'Copy Command';

  @override
  String get aiRefineSearch => 'Refine search with AI';

  @override
  String get aiExplainUpdate => 'Explain this update';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowRestore => 'Restore';

  @override
  String get windowClose => 'Close';

  @override
  String get omnistore => 'OmniStore';

  @override
  String get installedApps => 'Installed Apps';

  @override
  String get githubStore => 'GitHub Store';

  @override
  String get flatpakStore => 'Flatpak Store';

  @override
  String get locateInstallation => 'Locate Installation';

  @override
  String get delete => 'Delete';

  @override
  String get welcomeTitle => 'Welcome to OmniStore';

  @override
  String get welcomeSubtitle =>
      'Providing a simple and elegant software management experience for Arch Linux';

  @override
  String get getStarted => 'Get Started';

  @override
  String get skip => 'Skip';

  @override
  String get envCheckTitle => 'Environment Check';

  @override
  String get envCheckSubtitle => 'Ensuring your system is ready';

  @override
  String get envFatalDesc =>
      'Your system doesn\'t seem to be Arch-based. Most features will be unavailable.';

  @override
  String get envWarningDesc =>
      'Some necessary components are missing. We can configure them for you.';

  @override
  String get envOkDesc => 'Everything is ready! Your system is perfect.';

  @override
  String get fixProblems => 'Fix / Configure All';

  @override
  String get continueAnyway => 'Continue Anyway';

  @override
  String get sourceConfigTitle => 'Software Sources';

  @override
  String get sourceConfigSubtitle =>
      'Choose where OmniStore may search for software';

  @override
  String get enableAur => 'Enable AUR (Arch User Repository)';

  @override
  String get yayDesc => 'Enabling AUR requires installing the yay helper.';

  @override
  String get aurWarning =>
      'Security Warning: AUR packages are user-contributed. Ensure you trust the source.';

  @override
  String get bootstrapNote =>
      'Browsing never requires authorization. Administrator authorization is requested only when setup changes the system.';

  @override
  String get feedbackDesc =>
      'If you encounter issues, please report them on GitHub.';

  @override
  String get aiAssistant => 'AI Assistant';

  @override
  String get aiAssistantDesc =>
      'Enable AI-powered search, app explanation, and error diagnosis.';

  @override
  String get aiProviderDesc => 'Select your AI model source (Local or Cloud)';

  @override
  String get aiEndpointHelper => 'Ollama defaults to http://localhost:11434';

  @override
  String get aiApiKeyHelper =>
      'Leave blank for Ollama, enter sk-xxx for OpenAI';

  @override
  String get howToGetApiKey => 'How to get an API key?';

  @override
  String get howToGetApiKeyDesc =>
      '1. Ollama (Local): Download and run Ollama, no key needed. 2. Cloud (OpenAI): Go to the provider\'s website, create an API Key, and enter it here.';

  @override
  String get gotIt => 'Got it';

  @override
  String get aiOllamaNote =>
      'Note: If using Ollama, ensure it\'s running with OLLAMA_ORIGINS=\"*\".';

  @override
  String get enterStore => 'Enter Store';

  @override
  String get nextStep => 'Next Step';

  @override
  String get resetCache => 'Reset Cache and History';

  @override
  String get resetCacheDesc =>
      'Clear search history and local recommendations cache';

  @override
  String get resetCacheConfirm =>
      'This will clear your search history and recommendations cache. Proceed?';

  @override
  String get resetting => 'Resetting...';

  @override
  String get resetSuccess => 'Cache and History cleared successfully';

  @override
  String resetFailed(String error) {
    return 'Reset failed: $error';
  }

  @override
  String get ollamaLocal => 'Ollama (Local)';

  @override
  String get openaiCompatible => 'OpenAI Compatible';

  @override
  String get googleGemini => 'Google Gemini';

  @override
  String get importPackages => 'Import Packages';

  @override
  String importPackagesConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Read $count packages from file. Start batch download?',
      one: 'Read 1 package from file. Start download?',
    );
    return '$_temp0';
  }

  @override
  String get allDownloads => 'Download All';

  @override
  String get importList => 'Import List';

  @override
  String get loadError =>
      'Failed to load recommendations, please check backend status';

  @override
  String get community => 'Community';

  @override
  String get official => 'Official';

  @override
  String get verified => 'Verified';

  @override
  String installingPkg(String name) {
    return 'Installing $name...';
  }

  @override
  String get switchSource => 'Switch';

  @override
  String get flatpakBetterDesc =>
      'Found a Flatpak source for this app, which is usually more stable.';

  @override
  String get aiAnalysisPrompt =>
      'Found error logs, do you need an AI analysis?';

  @override
  String get analyzeNow => 'Analyze Now';

  @override
  String get cleanOrphans => 'Clean unused dependencies (orphans)';

  @override
  String get securityWarning => 'Security Warning';

  @override
  String get aurSecurityDesc =>
      'AUR (Arch User Repository) is a community-maintained repository. Since anyone can upload packages, there might be insecure code. Before installing, it is recommended to check the PKGBUILD.';

  @override
  String get continueInstall => 'Continue Install';

  @override
  String get installInfo => 'Installation Info';

  @override
  String get downloadSize => 'Download Size';

  @override
  String get installedSize => 'Installed Size';

  @override
  String dependenciesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dependencies ($count)',
      one: 'Dependency (1)',
    );
    return '$_temp0';
  }

  @override
  String get runningInBackground =>
      'OmniStore is running in the background, you can open it via the tray icon.';

  @override
  String get clearSearch => 'Clear Search';

  @override
  String get listView => 'List View';

  @override
  String get gridView => 'Grid View';

  @override
  String get categories => 'Categories';

  @override
  String get clearHistory => 'Clear History';

  @override
  String get clearHistoryShort => 'Clear History';

  @override
  String get confirmClearHistory =>
      'Are you sure you want to clear all history?';

  @override
  String get viewMore => 'View More';

  @override
  String get logDebug => 'DEBUG';

  @override
  String get logInfo => 'INFO';

  @override
  String get logWarning => 'WARNING';

  @override
  String get logError => 'ERROR';

  @override
  String get notificationTitle => 'Updates Available';

  @override
  String notificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count applications are available for update',
      one: '1 application is available for update',
    );
    return '$_temp0';
  }

  @override
  String get preparingUpdate => 'Preparing update...';

  @override
  String get processing => 'Processing';

  @override
  String get clear => 'Clear';

  @override
  String get retry => 'Retry';

  @override
  String get searchFailedSubtitle =>
      'The software sources could not be reached. Check your connection and try again.';

  @override
  String pluginCapabilities(int count) {
    return '$count capabilities';
  }

  @override
  String get aiResponseFailed => 'AI failed to respond.';

  @override
  String get aiAnalysisFailed => 'AI failed to analyze.';

  @override
  String cannotConnectToBackend(String error) {
    return 'Cannot connect to backend service: $error';
  }

  @override
  String get taskInitializing => 'Initializing task...';

  @override
  String get taskStarting => 'Starting...';

  @override
  String get taskSuccess => 'Task completed successfully';

  @override
  String taskFailedWithCode(int code) {
    return 'Task failed with exit code $code';
  }

  @override
  String get taskCancelledByUser => 'Task cancelled by user';

  @override
  String taskError(String error) {
    return 'Error: $error';
  }

  @override
  String get githubAuthTitle => 'GitHub Authentication';

  @override
  String get githubPatSaved => 'GitHub PAT saved successfully';

  @override
  String get saveToken => 'Save Token';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get aurFull => 'AUR (Arch User Repository)';

  @override
  String get flatpakFull => 'Flatpak (Flathub)';

  @override
  String get errorPackageNameRequired => 'Error: Package name cannot be empty';

  @override
  String errorStartFailed(String error) {
    return 'Failed to start: $error';
  }

  @override
  String errorUpdateFailed(String error) {
    return 'Update failed: $error';
  }

  @override
  String checkUpdateFailed(String error) {
    return 'Check update failed: $error';
  }

  @override
  String errorCleanFailed(String error) {
    return 'Cleanup failed: $error';
  }

  @override
  String errorFatalStream(String error) {
    return 'Fatal data stream error: $error';
  }

  @override
  String errorProcessStart(String error) {
    return 'Process start failed, please check environment: $error';
  }

  @override
  String get taskForcedTerminated => 'Task forcibly terminated';

  @override
  String get aiTimeout => 'AI connection timed out, please try again later.';

  @override
  String get aiNoResponse => 'AI failed to provide a valid response.';

  @override
  String get aiParseFailed => 'AI response parsing failed: incorrect format.';

  @override
  String aiCallFailed(String error) {
    return 'AI service call failed: $error';
  }

  @override
  String errorUpdateAll(String error) {
    return 'Update all error: $error';
  }

  @override
  String get taskProcessing => 'Processing';

  @override
  String get collapse => 'Collapse';

  @override
  String get expand => 'Expand';

  @override
  String get all => 'All';

  @override
  String get relatedApps => 'Related Apps';

  @override
  String get activeSources => 'Active Sources';

  @override
  String get autoDetect => 'Auto Detect';

  @override
  String get addCustomSource => 'Add Custom Source';

  @override
  String get addCustomSourceDesc =>
      'Configure custom Pacman/Flatpak repositories, AppImage feeds, or GitHub/Bitu sources';

  @override
  String get pacmanRepoType => 'Pacman repository';

  @override
  String get pacmanRepoSafety =>
      'Only HTTPS repositories with required package signatures are accepted. OmniStore never downloads signing keys or runs pacman -Sy. The source takes effect during the next full system upgrade.';

  @override
  String get sourceType => 'Source Type';

  @override
  String get githubRepoType => 'GitHub Repository (owner/repo)';

  @override
  String get bituRepoType => 'Bitu / Bitbucket (workspace/repo)';

  @override
  String get flatpakRemoteType => 'Flatpak Remote';

  @override
  String get appImageFeedType => 'AppImage Feed URL';

  @override
  String get sourceName => 'Source Name';

  @override
  String get hintCustomAppName => 'e.g. my-custom-app';

  @override
  String get repoOwnerRepo => 'Repository (owner/repo)';

  @override
  String get sourceUrl => 'URL';

  @override
  String get hintRepoFormat => 'e.g. flutter/flutter';

  @override
  String get hintFeedUrl => 'e.g. https://example.com/feed.json';

  @override
  String get errorNameUrlRequired => 'Name and URL/Repo cannot be empty';

  @override
  String get addingCustomSource => 'Adding custom source...';

  @override
  String get sourceAddSuccess => 'Source added successfully!';

  @override
  String get sourceAddFailed => 'Failed to add source.';

  @override
  String get autoDetectingSources =>
      'Auto-detecting available sources for your system...';

  @override
  String get autoDetectSuccess => 'Auto-detection complete and settings saved!';

  @override
  String get autoDetectFailed => 'Failed to save auto-detected settings.';

  @override
  String get personalAccessToken => 'Personal Access Token';

  @override
  String get copyName => 'Copy Name';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get tapToCopy => 'Tap to copy';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle => 'Requires restart to take effect';

  @override
  String get restartTitleBar => 'Please restart to apply title bar changes';

  @override
  String get enableDaemon => 'Enable Background Update Daemon';

  @override
  String get enableDaemonDesc =>
      'Regularly check for updates in the background';

  @override
  String get autoUpdate => 'Silent Auto Update';

  @override
  String get autoUpdateDesc =>
      'Automatically download and update all packages in the background';

  @override
  String get checkIntervalTitle => 'Update Check Frequency';

  @override
  String checkIntervalSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Automatically check every $hours hours',
      one: 'Automatically check every hour',
    );
    return '$_temp0';
  }

  @override
  String get typography => 'Typography';

  @override
  String get fontFamily => 'Font Family';

  @override
  String get fontScale => 'Font Scale';

  @override
  String get systemDefault => 'System Default';

  @override
  String hourValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String get langSimplifiedChinese => 'Simplified Chinese';

  @override
  String get langTraditionalChinese => 'Traditional Chinese';

  @override
  String get langEnglish => 'English';

  @override
  String get langJapanese => 'Japanese';

  @override
  String get langSpanish => 'Spanish';

  @override
  String get taskInProgress => 'Another task is already in progress';

  @override
  String get trayInitFailedDisabled =>
      'System tray initialization failed. Close to tray disabled.';

  @override
  String get errorTitle => 'Error';

  @override
  String get appDetailsNotFound => 'App details not found';

  @override
  String diskSpaceInfo(String free, String total) {
    return 'Disk Space: $free GB free / $total GB total';
  }

  @override
  String cacheTypeInfo(String pacman, String flatpak, String custom) {
    return 'Pacman: $pacman MB | Flatpak: $flatpak MB | Custom: $custom MB';
  }

  @override
  String get backSemanticsLabel => 'Back';

  @override
  String get backSemanticsHint => 'Go back to the previous screen';

  @override
  String categorySemantics(String name) {
    return 'Category: $name';
  }

  @override
  String get temperatureRangeError => 'Value must be between 0.0 and 2.0';

  @override
  String get enableSystemdService => 'Enable systemd Background Service';

  @override
  String get enableSystemdServiceDesc =>
      'Allow registering systemd timer to check for updates when the app is closed';

  @override
  String get taskHistory => 'Task History';

  @override
  String get unknownApp => 'Unknown App';

  @override
  String get taskSuccessMsg => 'Completed successfully';

  @override
  String failureReason(String message) {
    return 'Failure reason: $message';
  }

  @override
  String get noPackagesAvailable => 'No packages available';

  @override
  String get noDescription => 'No description provided.';

  @override
  String get viewDetails => 'View Details';

  @override
  String get ok => 'OK';

  @override
  String get checkNetwork => 'Check your network connection and try again';

  @override
  String get githubStoreSubtitle =>
      'Discover and download apps directly from GitHub releases';

  @override
  String get searchGithubHint => 'Search GitHub repositories...';

  @override
  String get recommended => 'Recommended';

  @override
  String get rankings => 'Rankings';

  @override
  String get trending => 'Trending';

  @override
  String get latestUpdates => 'Latest Updates';

  @override
  String get searchNoResultsSubtitle =>
      'Try another keyword or enable more software sources';

  @override
  String get pluginsAndSources => 'Plugins & Sources';

  @override
  String get refreshPlugins => 'Refresh plugins';

  @override
  String get noPluginsFound => 'No source plugins found';

  @override
  String get builtin => 'Builtin';

  @override
  String get legacy => 'Legacy';

  @override
  String get pluginUpdated => 'Plugin updated';

  @override
  String get pluginUpdateFailed => 'Plugin update failed';

  @override
  String get pluginRemoved => 'Plugin removed';

  @override
  String get pluginRemovalFailed => 'Plugin removal failed';

  @override
  String get removePlugin => 'Remove plugin';

  @override
  String get managed => 'Managed';

  @override
  String get readOnly => 'Read-only';

  @override
  String get installationDecisionTitle => 'Installation Decision Helper';

  @override
  String recommendedSource(String source) {
    return 'Recommended Source: $source';
  }

  @override
  String get preflightChecks => 'Preflight Checks';

  @override
  String get potentialRisks => 'Potential Risks';

  @override
  String get continueInstallation => 'Continue';

  @override
  String get changeRecommendation => 'Change recommendation';

  @override
  String get aiPickDisclaimer =>
      'Generated based on your search, installation history, and currently available sources; will not affect your installation choices.';

  @override
  String get quickStart => 'Quick Start';

  @override
  String get importListSubtitle =>
      'Import your frequently used packages from a list';

  @override
  String get emptyTrendingMessage =>
      'No trending data available; it will automatically update when connection is restored.';

  @override
  String get emptyRecommendationsMessage =>
      'Personalized suggestions will appear here after you search or install apps.';

  @override
  String get aiPickFallbackMessage =>
      'Unable to generate personalized recommendations at this time. You can still browse editor picks or try again later.';

  @override
  String get meoarchAccount => 'MeoArch Account';

  @override
  String get defaultUser => 'User';

  @override
  String get signOut => 'Sign Out';

  @override
  String get syncStatus => 'Sync Status';

  @override
  String get syncStatusSubtitle => 'Tap to back up your OmniStore app list';

  @override
  String get manageAccount => 'Manage Account';

  @override
  String get manageAccountSubtitle => 'Security, MFA, and sessions';

  @override
  String get signInTitle => 'Sign In to MeoArch';

  @override
  String get signInSubtitle =>
      'Sync your apps, settings, and favorites across devices.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signIn => 'Sign In';

  @override
  String get createAccount => 'Create MeoArch Account';

  @override
  String get orDivider => 'OR';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithGitHub => 'Continue with GitHub';

  @override
  String get enterEmailAndPassword => 'Please enter email and password.';

  @override
  String signInFailed(String message) {
    return 'Sign in failed: $message';
  }

  @override
  String signInError(String message) {
    return 'Sign in error: $message';
  }

  @override
  String get githubIntegration => 'GitHub Integration';

  @override
  String get configurePat => 'GitHub access token (optional)';

  @override
  String get patHelperText =>
      'Provide a GitHub Classic PAT or Fine-grained Token.';

  @override
  String get featuredSubtitle =>
      'Maintained by OmniStore, available even offline';

  @override
  String get editorPicks => 'Editor\'s Choice';

  @override
  String get checkingEnvStatus => 'Checking environment status...';

  @override
  String get envDetailsFailed => 'Failed to fetch environment details.';

  @override
  String get bootstrapProgress => 'Bootstrap progress:';

  @override
  String get systemDetails => 'System details:';

  @override
  String get aiIntegrationDesc => 'Enable intelligence integration features';

  @override
  String get ollamaLocalOffline => 'Ollama (Local / Offline)';

  @override
  String get openaiCloud => 'OpenAI API (Cloud)';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get githubSearchFailed => 'GitHub search failed';

  @override
  String get githubStoreUnavailable => 'GitHub Store unavailable';

  @override
  String get noGithubReposFound => 'No GitHub repositories found';

  @override
  String get pullToRefreshCategory =>
      'Pull to refresh or try another category.';

  @override
  String sourceFilterSemantics(String name) {
    return 'Filter by source: $name';
  }

  @override
  String get meoChannelTitle => 'Meo Update Channel';

  @override
  String get meoChannelSubtitle =>
      'Read from the active pacman repository order';

  @override
  String get meoChannelBetaNotice =>
      'Beta receives newer Meo components before Stable. Arch system packages stay on their normal repositories.';

  @override
  String get meoChannelStableNotice =>
      'Stable receives fully tested MeoArch release trains.';

  @override
  String repoPriority(String repos) {
    return 'Repository priority: $repos';
  }

  @override
  String get betaWarningPanel =>
      'Beta is opt-in and is not recommended for critical systems. Stable remains the fallback repository.';

  @override
  String downgradeReviewPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Stable is configured, but $count Meo package downgrades still require review.',
      one:
          'Stable is configured, but 1 Meo package downgrade still requires review.',
    );
    return '$_temp0';
  }

  @override
  String get reviewDowngrades => 'Review Downgrades';

  @override
  String get switchToStable => 'Switch to Stable';

  @override
  String downgradeNotice(String packages) {
    return 'The following official Meo packages need a Stable version. Arch and third-party packages will not be downgraded.\n\n$packages';
  }

  @override
  String get channelStable => 'Stable';

  @override
  String get channelBeta => 'Beta';

  @override
  String get download => 'Download';

  @override
  String get systemAiProviderLabel =>
      'System AI connection (KWallet / Recommended)';

  @override
  String get systemAiSharedConnectionLabel => 'System shared connection';

  @override
  String get systemAiConnectionHelper =>
      'Meo Account reads the key from KWallet; OmniStore cannot read the plaintext.';

  @override
  String get systemAiLoadingTitle => 'Reading system AI connections';

  @override
  String get systemAiMetadataOnly =>
      'Only names, endpoints, and default models are read; keys are never read.';

  @override
  String get systemAiLoadErrorTitle => 'Unable to read system AI connections';

  @override
  String get systemAiSelectLabel => 'AI connection on this device';

  @override
  String get meoSettingsOpenFailed => 'Unable to open Meo Settings.';

  @override
  String get manageInMeoSettings => 'Manage in Meo Settings';

  @override
  String get systemAiNoConnections =>
      'No system AI connection is configured. Add one in Meo Settings first.';

  @override
  String get systemAiLoadFailed =>
      'Unable to read system AI connections. Check Accounts & Security in Meo Settings.';

  @override
  String get systemAiInvalidCatalog =>
      'The system AI service returned an invalid model catalog.';

  @override
  String get systemAiInvalidConsent =>
      'The system AI service did not return a valid consent summary.';

  @override
  String get systemAiConsentExpired =>
      'The system AI consent summary is invalid or expired.';

  @override
  String get systemAiInvalidResponse =>
      'The system AI service did not return valid text.';

  @override
  String get systemAiUnsupported =>
      'System AI is not supported on this platform.';

  @override
  String get systemAiOperationFailed => 'The system AI operation failed.';

  @override
  String get systemAiTimeout => 'The system AI operation timed out.';

  @override
  String get systemAiUnavailable =>
      'Unable to connect to the Meo Account system AI service.';

  @override
  String get systemAiTestPurpose => 'Test the OmniStore system AI connection';

  @override
  String get aiConsentCancelled => 'You cancelled this AI request.';

  @override
  String get chooseSystemAiConnection =>
      'Select a system AI connection in OmniStore Settings first.';

  @override
  String get chooseAccountAiConnection =>
      'Select an account AI connection in OmniStore Settings first.';

  @override
  String get aiConfigUnavailable => 'AI configuration is unavailable.';

  @override
  String get aiNotEnabled => 'AI assistance is not enabled.';

  @override
  String get aiAccountProviderHint =>
      'Meo Account invokes your saved connection; the API key is never sent to OmniStore.';

  @override
  String get aiSystemProviderHint =>
      'Meo Account invokes the connection from KWallet; OmniStore sees only metadata and the final result.';

  @override
  String get aiOllamaProviderHint =>
      'Ollama connects only to the local service and does not require an API key.';

  @override
  String get aiCompatibleProviderHint =>
      'Use only a trusted HTTPS-compatible endpoint; the key remains in the local secure store.';

  @override
  String get aiLocalKeyProviderHint =>
      'This provider has a separate key in Secret Service/KWallet that cannot be read back.';

  @override
  String get meoAccountOpenFailed => 'Unable to open Meo Account.';

  @override
  String get secureCredentialWriteFailed =>
      'Unable to write to the system credential store.';

  @override
  String get modelsNoneFound =>
      'The service is running, but no installed or available models were reported.';

  @override
  String get modelsAutofilled =>
      'A discovered model was filled in automatically.';

  @override
  String get modelsFoundChoose =>
      'Models were found. Choose one before testing; OmniStore does not infer capabilities from names.';

  @override
  String get apiKeyRequired => 'Enter a new API key first.';

  @override
  String get secureCredentialSaved =>
      'The API key was saved to the system credential store.';

  @override
  String get localApiKeyDeleted => 'The local API key was deleted.';

  @override
  String get secureCredentialUnavailable =>
      'Unable to access the system credential store.';

  @override
  String get signInMeoAccount => 'Sign in to Meo Account';

  @override
  String get signInMeoAccountDetail =>
      'After signing in, choose an encrypted account AI connection. Its API key is never sent to OmniStore.';

  @override
  String get accountAiLoading => 'Reading account AI connections';

  @override
  String get accountAiMetadataOnly =>
      'Only names, providers, and masked key status are read.';

  @override
  String get accountAiLoadError => 'Unable to read account AI connections';

  @override
  String get accountAiNone => 'No AI connection is saved in this account';

  @override
  String get accountAiNoneDetail =>
      'Add your API key securely in Account, then return here and refresh.';

  @override
  String get connect => 'Connect';

  @override
  String get accountAiSelectLabel => 'Account AI connection';

  @override
  String get accountAiConnectionHelper =>
      'The key is decrypted only inside the Account Edge broker; OmniStore cannot read it.';

  @override
  String get manageAiConnections => 'Manage AI connections';

  @override
  String get aiPerRequestConsentDetail =>
      'Before every request, OmniStore shows the provider, model, purpose, data categories, full content, and request fingerprint, then asks for one-time consent.';

  @override
  String get aiEnabledConsentDesc =>
      'Off by default; every request still requires separate confirmation after it is enabled.';

  @override
  String providerLocalSecureKey(String provider) {
    return '$provider (local secure key)';
  }

  @override
  String get providerCompatibleHttps => 'OpenAI Compatible (custom HTTPS)';

  @override
  String get providerMeoAccount => 'Meo Account';

  @override
  String get ollamaEndpointSafety =>
      'Defaults to local Ollama. Keep a loopback address to avoid contacting a LAN service accidentally.';

  @override
  String get compatibleEndpointSafety =>
      'Enter only a trusted HTTPS-compatible endpoint without a key or query parameters.';

  @override
  String get accountModelOverride => 'Account model';

  @override
  String get accountModelDefaultHelper =>
      'Leave empty to use the selected Account connection\'s default model.';

  @override
  String get modelReviewHelper =>
      'The actual model is shown again for confirmation before every request.';

  @override
  String get detectLocalModels => 'Detect local models and fill one in';

  @override
  String get readModelCatalog => 'Read model catalog';

  @override
  String get installOllamaWithOmniStore => 'Install Ollama with OmniStore';

  @override
  String get chooseDiscoveredModel => 'Choose a discovered model';

  @override
  String get localKeyStored =>
      'A separate secure key is saved for this provider';

  @override
  String get localKeyNotStored => 'No API key is saved for this provider';

  @override
  String get localKeysHelper =>
      'Each provider is stored separately in Secret Service/KWallet; keys can be replaced or deleted but never read back.';

  @override
  String get newApiKeyLabel => 'New API key (cleared after saving)';

  @override
  String get newApiKeyHelper =>
      'Enter only a replacement key. Existing keys cannot be read or copied.';

  @override
  String get hideInput => 'Hide input';

  @override
  String get showInput => 'Show input';

  @override
  String get saveOrReplace => 'Save securely / Replace';

  @override
  String get deleteLocalKey => 'Delete local key';

  @override
  String get temperatureHelper =>
      '0–2; lower values are usually more stable, and out-of-range values are not saved.';

  @override
  String get aiTestScopeHelper =>
      'Testing checks only the current connection and does not change the AI enable switch; real requests still require one-time consent.';

  @override
  String get meoUpdateChannel => 'Meo update channel';

  @override
  String get meoUpdateChannelSubtitle =>
      'Read from your active Pacman repositories';

  @override
  String get meoChannelChecking => 'Checking update channel…';

  @override
  String get meoChannelStable => 'Stable';

  @override
  String get meoChannelBeta => 'Beta';

  @override
  String get meoChannelBetaSummary =>
      'Get newer Meo components before Stable. Arch system packages keep their normal repositories.';

  @override
  String get meoChannelStableSummary =>
      'Get fully tested MeoArch release trains.';

  @override
  String meoChannelRepositoryPriority(String repositories) {
    return 'Repository priority: $repositories';
  }

  @override
  String meoChannelDowngradePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Stable is selected, but $count Meo package downgrades still need your review.',
      one:
          'Stable is selected, but 1 Meo package downgrade still needs your review.',
    );
    return '$_temp0';
  }

  @override
  String get meoChannelReviewDowngrades => 'Review downgrades';

  @override
  String get meoChannelSwitchToStable => 'Switch to Stable';

  @override
  String get meoChannelRollbackPreviewInvalid =>
      'This Stable rollback preview is no longer valid. Refresh it and review it again.';

  @override
  String meoChannelDowngradeDialog(String packages) {
    return 'These official Meo packages will move to their Stable versions. Arch and third-party packages won\'t be downgraded.\\n\\n$packages';
  }

  @override
  String get aiConsentTitle => 'Review this AI request';

  @override
  String get aiConsentIntro =>
      'Review the exact request before sending it. Your confirmation applies only to this request and its fingerprint.';

  @override
  String get aiConsentProvider => 'Provider';

  @override
  String get aiConsentDestination => 'Destination';

  @override
  String get aiConsentModel => 'Model';

  @override
  String get aiConsentPurpose => 'Purpose';

  @override
  String get aiConsentDataCategories => 'Data included';

  @override
  String get aiConsentCharacters => 'Characters';

  @override
  String get aiConsentFingerprint => 'Fingerprint';

  @override
  String get aiConsentReviewContent => 'Review content to be sent';

  @override
  String get aiConsentSystemInstruction => 'System instruction';

  @override
  String get aiConsentUserContent => 'Your content';

  @override
  String aiConsentConfirmWithProvider(String provider) {
    return 'I understand this content will be sent to $provider.';
  }

  @override
  String get aiConsentKeyNotExposed =>
      'Your API key is not part of this prompt and is not shown here.';

  @override
  String get aiConsentDeny => 'Don\'t send';

  @override
  String get aiConsentAllowOnce => 'Confirm and send once';

  @override
  String get aiConsentCategoryAppName => 'App name';

  @override
  String get aiConsentCategoryAppDescription => 'App description';

  @override
  String get aiConsentCategoryVersionMetadata => 'Version information';

  @override
  String get aiConsentCategoryPackageSource => 'Package source';

  @override
  String get aiConsentCategoryPackageVariants => 'Installation options';

  @override
  String get aiConsentCategoryPreferenceRequest => 'Preference request';

  @override
  String get aiConsentCategorySearchQuery => 'Search query';

  @override
  String get aiConsentCategorySystemEnvironment => 'System environment summary';

  @override
  String get aiConsentCategoryErrorLog => 'Error log';

  @override
  String get aiConsentCategoryRecommendationRequest => 'Recommendation request';

  @override
  String get aiConsentCategoryConnectionTest => 'Connection test data';

  @override
  String get githubLoadErrorDetail =>
      'Could not load GitHub repositories. Check your network and try again.';

  @override
  String get githubSearchErrorDetail =>
      'Could not search GitHub repositories. Check your network and try again.';

  @override
  String get flatpakLoadErrorDetail =>
      'Could not load Flatpak apps. Check Flathub and your network connection, then try again.';

  @override
  String appCardSemantics(String name) {
    return 'App: $name';
  }

  @override
  String get diskSize => 'Disk size';

  @override
  String diskSizeWithConfidence(String confidence) {
    return 'Disk size ($confidence)';
  }

  @override
  String get accountAiSignInRequired =>
      'Sign in to Meo Account before using Account AI.';

  @override
  String get accountAiNoDefaultModel =>
      'This AI connection has no default model. Choose a model in Settings first.';

  @override
  String get accountAiInvalidConsent =>
      'The account AI service did not return a valid consent summary.';

  @override
  String get accountAiConsentExpired =>
      'The AI consent summary is invalid or expired.';

  @override
  String get accountAiInvalidResponse =>
      'The AI service did not return valid content.';

  @override
  String get accountAiTestPurpose => 'Test the OmniStore account AI connection';

  @override
  String get accountAiInvalidDestination =>
      'The account AI connection has an invalid destination.';

  @override
  String get accountAiConnectionNotFound =>
      'The selected AI connection is unavailable. Choose it again in Settings.';

  @override
  String get accountAiInvalidData =>
      'The account AI service returned invalid data.';

  @override
  String get accountAiUnavailable =>
      'The account AI service is temporarily unavailable.';

  @override
  String get accountAiRequestDenied =>
      'The account AI request was denied. Sign in again and try once more.';

  @override
  String get accountAiConnectionFailed =>
      'Unable to connect to the account AI service.';

  @override
  String get localAiUnsupportedModelDiscovery =>
      'This connection does not support local model discovery.';

  @override
  String get localAiCredentialStoreUnavailable =>
      'Unable to open the secure credential store. Unlock KWallet and try again.';

  @override
  String get localAiApiKeyRequired =>
      'Securely save an API key for this provider first.';

  @override
  String get localAiCatalogTooLarge =>
      'The model catalog response is too large.';

  @override
  String get localAiInvalidCatalog =>
      'The model catalog returned invalid data.';

  @override
  String get localAiCatalogUnavailable =>
      'Unable to read the model catalog. Check that the service is running.';

  @override
  String get localAiUnsupportedConnection =>
      'This local AI connection type is not supported.';

  @override
  String get localAiInvalidModel => 'Enter a valid model name.';

  @override
  String get localAiInvalidPurpose => 'The AI request purpose is invalid.';

  @override
  String get localAiInvalidInput => 'The AI input is empty or too large.';

  @override
  String get localAiInvalidDataCategories =>
      'The AI data categories are invalid.';

  @override
  String get localAiApiKeyInvalid =>
      'The secure credential store has no valid API key for this provider.';

  @override
  String get localAiDestinationChanged =>
      'The AI destination changed after consent, so the request was blocked.';

  @override
  String get localAiResponseTooLarge => 'The AI service response is too large.';

  @override
  String get localAiInvalidResponse => 'The AI service returned invalid data.';

  @override
  String get localAiNoResponseText => 'The AI service did not return text.';

  @override
  String get localAiConnectionFailed =>
      'Unable to connect to the AI service, or the request timed out.';

  @override
  String get localAiTestPurpose =>
      'Test the OmniStore local secure AI connection';

  @override
  String get localAiInvalidEndpoint => 'The AI service address is invalid.';

  @override
  String get localAiOllamaLoopbackRequired =>
      'The Ollama address must use local HTTP(S) loopback.';

  @override
  String get localAiHttpsRequired => 'Cloud AI services must use HTTPS.';

  @override
  String get localAiPrivateEndpointBlocked =>
      'A compatible API cannot point to a local or private network. Use Ollama for local models.';

  @override
  String get localAiOllama => 'Ollama (on this device)';

  @override
  String get localAiApiKeyRejected => 'The AI service rejected the API key.';

  @override
  String get localAiModelOrEndpointNotFound =>
      'The requested AI model or service address was not found.';

  @override
  String get localAiRateLimited =>
      'The AI service is out of quota or receiving requests too quickly.';

  @override
  String get localAiUnavailable => 'The AI service is temporarily unavailable.';

  @override
  String localAiRequestRejected(int status) {
    return 'The AI service rejected the request (HTTP $status).';
  }

  @override
  String get aiTestService => 'Service';

  @override
  String get aiTestConnected => 'Connected';

  @override
  String get aiTestUnavailable => 'Unavailable';

  @override
  String get aiTestReady => 'Ready';

  @override
  String get aiTestNotReady => 'Not ready';

  @override
  String get aiTestLatency => 'Latency';

  @override
  String featuredAppSemantics(String name) {
    return 'Featured app: $name';
  }
}
