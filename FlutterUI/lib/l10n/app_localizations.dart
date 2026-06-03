import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('ja'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// Description for searchHint
  ///
  /// In en, this message translates to:
  /// **'Search apps, games, tools...'**
  String get searchHint;

  /// Description for featured
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featured;

  /// Description for forYou
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get forYou;

  /// Description for essentialTools
  ///
  /// In en, this message translates to:
  /// **'Essential Tools'**
  String get essentialTools;

  /// Description for hotApps
  ///
  /// In en, this message translates to:
  /// **'Hot Apps'**
  String get hotApps;

  /// Description for explore
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// Description for search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Description for settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Description for downloads
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// Description for help
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// Description for userAccount
  ///
  /// In en, this message translates to:
  /// **'User Account'**
  String get userAccount;

  /// Description for install
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// Description for open
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// Description for uninstall
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get uninstall;

  /// Description for launch
  ///
  /// In en, this message translates to:
  /// **'Launch'**
  String get launch;

  /// Description for about
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Description for details
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// Description for source
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// Description for variant
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get variant;

  /// Description for version
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// Description for ready
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @resultsFound.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String resultsFound(int count);

  /// Description for noResults
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// Description for searching
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get searching;

  /// Activity tab label
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// Category label
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// Description for packageManager
  ///
  /// In en, this message translates to:
  /// **'Package Manager'**
  String get packageManager;

  /// Description for pacmanOfficial
  ///
  /// In en, this message translates to:
  /// **'Pacman (Official)'**
  String get pacmanOfficial;

  /// Description for aurUser
  ///
  /// In en, this message translates to:
  /// **'AUR (User)'**
  String get aurUser;

  /// Description for flatpak
  ///
  /// In en, this message translates to:
  /// **'Flatpak'**
  String get flatpak;

  /// Description for appImage
  ///
  /// In en, this message translates to:
  /// **'AppImage'**
  String get appImage;

  /// Description for sourcePriority
  ///
  /// In en, this message translates to:
  /// **'Source Priority (Drag to reorder)'**
  String get sourcePriority;

  /// Description for maxResults
  ///
  /// In en, this message translates to:
  /// **'Max Results'**
  String get maxResults;

  /// Description for appearance
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Description for themeColor
  ///
  /// In en, this message translates to:
  /// **'Theme Color Seed'**
  String get themeColor;

  /// Description for followSystem
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get followSystem;

  /// Description for lightMode
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// Description for darkMode
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Description for loggingLevel
  ///
  /// In en, this message translates to:
  /// **'Logging Level'**
  String get loggingLevel;

  /// Description for saveAndApply
  ///
  /// In en, this message translates to:
  /// **'Save and Apply'**
  String get saveAndApply;

  /// Description for configSaved
  ///
  /// In en, this message translates to:
  /// **'Configuration saved'**
  String get configSaved;

  /// Description for configSaveFailed
  ///
  /// In en, this message translates to:
  /// **'Failed to save configuration'**
  String get configSaveFailed;

  /// Description for confirmUninstall
  ///
  /// In en, this message translates to:
  /// **'Confirm Uninstall'**
  String get confirmUninstall;

  /// Description for confirmInstall
  ///
  /// In en, this message translates to:
  /// **'Confirm Install'**
  String get confirmInstall;

  /// No description provided for @confirmActionMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to perform this action on {name}?'**
  String confirmActionMsg(String name);

  /// Description for cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Description for confirm
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Description for terminalOutput
  ///
  /// In en, this message translates to:
  /// **'Terminal Output'**
  String get terminalOutput;

  /// Description for waitingForOutput
  ///
  /// In en, this message translates to:
  /// **'Waiting for output...'**
  String get waitingForOutput;

  /// Description for screenshots
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get screenshots;

  /// Description for developer
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// Description for license
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// Description for success
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// Description for failed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// Description for taskCancelled
  ///
  /// In en, this message translates to:
  /// **'Task Cancelled'**
  String get taskCancelled;

  /// Description for catDevelopment
  ///
  /// In en, this message translates to:
  /// **'Development'**
  String get catDevelopment;

  /// Description for catMedia
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get catMedia;

  /// Description for catInternet
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get catInternet;

  /// Description for catSystem
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get catSystem;

  /// Description for catOffice
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get catOffice;

  /// Description for catGames
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get catGames;

  /// Category for Graphics
  ///
  /// In en, this message translates to:
  /// **'Graphics'**
  String get catGraphics;

  /// Category for Utility
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get catUtility;

  /// Section title for system and window settings
  ///
  /// In en, this message translates to:
  /// **'System & Window'**
  String get systemAndWindow;

  /// Tooltip for visiting website
  ///
  /// In en, this message translates to:
  /// **'Visit Website'**
  String get visitWebsite;

  /// Description for updates
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updates;

  /// Description for upToDate
  ///
  /// In en, this message translates to:
  /// **'All apps are up to date'**
  String get upToDate;

  /// Description for checkUpdates
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkUpdates;

  /// No description provided for @foundUpdates.
  ///
  /// In en, this message translates to:
  /// **'Found {count} updates'**
  String foundUpdates(int count);

  /// Description for updateAll
  ///
  /// In en, this message translates to:
  /// **'Update All'**
  String get updateAll;

  /// Description for notifications
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Description for enableNotifications
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get enableNotifications;

  /// Description for progressNotifications
  ///
  /// In en, this message translates to:
  /// **'Progress Notifications'**
  String get progressNotifications;

  /// Description for completionNotifications
  ///
  /// In en, this message translates to:
  /// **'Completion Notifications'**
  String get completionNotifications;

  /// Description for closeToTray
  ///
  /// In en, this message translates to:
  /// **'Close to system tray'**
  String get closeToTray;

  /// Description for useSystemTitleBar
  ///
  /// In en, this message translates to:
  /// **'Use system title bar'**
  String get useSystemTitleBar;

  /// Description for showWindow
  ///
  /// In en, this message translates to:
  /// **'Show Window'**
  String get showWindow;

  /// Description for exit
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// Description for trayTooltipUpdates
  ///
  /// In en, this message translates to:
  /// **'OmniStore: Found {count} updates'**
  String trayTooltipUpdates(int count);

  /// Description for trayTooltipUpToDate
  ///
  /// In en, this message translates to:
  /// **'OmniStore: Up to date'**
  String get trayTooltipUpToDate;

  /// Description for updateReminders
  ///
  /// In en, this message translates to:
  /// **'Update Reminders'**
  String get updateReminders;

  /// Description for maintenance
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenance;

  /// Description for updateAllPackages
  ///
  /// In en, this message translates to:
  /// **'Update All Packages'**
  String get updateAllPackages;

  /// Description for includeAurUpdates
  ///
  /// In en, this message translates to:
  /// **'Include AUR in \'Update All\''**
  String get includeAurUpdates;

  /// Description for resetOnboarding
  ///
  /// In en, this message translates to:
  /// **'Reset Onboarding (Welcome Page)'**
  String get resetOnboarding;

  /// Description for resetOnboardingConfirm
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset onboarding? The welcome page will show on next launch.'**
  String get resetOnboardingConfirm;

  /// Description for checkInterval
  ///
  /// In en, this message translates to:
  /// **'Update Check Interval (Hours)'**
  String get checkInterval;

  /// Description for remindMeOfUpdates
  ///
  /// In en, this message translates to:
  /// **'Remind Me of Updates'**
  String get remindMeOfUpdates;

  /// No description provided for @installingApp.
  ///
  /// In en, this message translates to:
  /// **'Installing {name}'**
  String installingApp(String name);

  /// No description provided for @uninstallingApp.
  ///
  /// In en, this message translates to:
  /// **'Uninstalling {name}'**
  String uninstallingApp(String name);

  /// Description for installSuccessTitle
  ///
  /// In en, this message translates to:
  /// **'Installation Successful'**
  String get installSuccessTitle;

  /// Description for uninstallSuccessTitle
  ///
  /// In en, this message translates to:
  /// **'Uninstallation Successful'**
  String get uninstallSuccessTitle;

  /// Description for installFailedTitle
  ///
  /// In en, this message translates to:
  /// **'Installation Failed'**
  String get installFailedTitle;

  /// Description for uninstallFailedTitle
  ///
  /// In en, this message translates to:
  /// **'Uninstallation Failed'**
  String get uninstallFailedTitle;

  /// Description for taskCompleted
  ///
  /// In en, this message translates to:
  /// **'Task Completed'**
  String get taskCompleted;

  /// searchInstalledHint
  ///
  /// In en, this message translates to:
  /// **'Search installed apps...'**
  String get searchInstalledHint;

  /// refresh
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// noActiveTasks
  ///
  /// In en, this message translates to:
  /// **'No active tasks'**
  String get noActiveTasks;

  /// currentTask
  ///
  /// In en, this message translates to:
  /// **'Current Task'**
  String get currentTask;

  /// viewLogs
  ///
  /// In en, this message translates to:
  /// **'View Logs'**
  String get viewLogs;

  /// allUpdated
  ///
  /// In en, this message translates to:
  /// **'All apps are up to date'**
  String get allUpdated;

  /// update
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// enableSystemTray
  ///
  /// In en, this message translates to:
  /// **'Enable system tray'**
  String get enableSystemTray;

  /// systemCleaning
  ///
  /// In en, this message translates to:
  /// **'System Cleaning'**
  String get systemCleaning;

  /// systemCleaningSubtitle
  ///
  /// In en, this message translates to:
  /// **'Delete orphan packages and clean pacman cache'**
  String get systemCleaningSubtitle;

  /// systemCleaningStarted
  ///
  /// In en, this message translates to:
  /// **'System cleaning task started'**
  String get systemCleaningStarted;

  /// backupAndExport
  ///
  /// In en, this message translates to:
  /// **'Backup and Export'**
  String get backupAndExport;

  /// backupAndExportSubtitle
  ///
  /// In en, this message translates to:
  /// **'Export current installed app list or import from backup'**
  String get backupAndExportSubtitle;

  /// export
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// import
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// selectExportLocation
  ///
  /// In en, this message translates to:
  /// **'Select export location'**
  String get selectExportLocation;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Export successful: {count} packages'**
  String exportSuccess(int count);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {message}'**
  String exportFailed(String message);

  /// importBackup
  ///
  /// In en, this message translates to:
  /// **'Import Backup'**
  String get importBackup;

  /// No description provided for @importBackupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Read {count} packages from backup. Start batch recovery?'**
  String importBackupConfirm(int count);

  /// startRecovery
  ///
  /// In en, this message translates to:
  /// **'Start Recovery'**
  String get startRecovery;

  /// mirrorListSaved
  ///
  /// In en, this message translates to:
  /// **'Mirror list saved'**
  String get mirrorListSaved;

  /// addMirror
  ///
  /// In en, this message translates to:
  /// **'Add Mirror'**
  String get addMirror;

  /// serverUrl
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// pacmanMirrorManagement
  ///
  /// In en, this message translates to:
  /// **'Pacman Mirror Management'**
  String get pacmanMirrorManagement;

  /// save
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// add
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// aiSettings
  ///
  /// In en, this message translates to:
  /// **'AI Assistant Settings'**
  String get aiSettings;

  /// aiEnabled
  ///
  /// In en, this message translates to:
  /// **'Enable AI Assistant'**
  String get aiEnabled;

  /// aiProvider
  ///
  /// In en, this message translates to:
  /// **'AI Provider'**
  String get aiProvider;

  /// aiEndpoint
  ///
  /// In en, this message translates to:
  /// **'API Endpoint'**
  String get aiEndpoint;

  /// aiModel
  ///
  /// In en, this message translates to:
  /// **'Model Name'**
  String get aiModel;

  /// aiApiKey
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get aiApiKey;

  /// aiProxy
  ///
  /// In en, this message translates to:
  /// **'Network Proxy (Optional)'**
  String get aiProxy;

  /// aiTemperature
  ///
  /// In en, this message translates to:
  /// **'Temperature (Creativity)'**
  String get aiTemperature;

  /// aiMaxTokens
  ///
  /// In en, this message translates to:
  /// **'Max Response Tokens'**
  String get aiMaxTokens;

  /// aiTestButton
  ///
  /// In en, this message translates to:
  /// **'Test AI Connection'**
  String get aiTestButton;

  /// aiTestSuccess
  ///
  /// In en, this message translates to:
  /// **'AI connection successful!'**
  String get aiTestSuccess;

  /// No description provided for @aiTestFailed.
  ///
  /// In en, this message translates to:
  /// **'AI connection failed: {error}'**
  String aiTestFailed(String error);

  /// aiPromptExplain
  ///
  /// In en, this message translates to:
  /// **'Explain with AI'**
  String get aiPromptExplain;

  /// aiPromptRecommend
  ///
  /// In en, this message translates to:
  /// **'Ask AI for Recommendation'**
  String get aiPromptRecommend;

  /// aiPromptError
  ///
  /// In en, this message translates to:
  /// **'Analyze Error with AI'**
  String get aiPromptError;

  /// aiPickDay
  ///
  /// In en, this message translates to:
  /// **'AI Pick of the Day'**
  String get aiPickDay;

  /// aiPickDaySubtitle
  ///
  /// In en, this message translates to:
  /// **'Powered by OmniStore AI'**
  String get aiPickDaySubtitle;

  /// aiCompareTitle
  ///
  /// In en, this message translates to:
  /// **'AI Variant Comparison'**
  String get aiCompareTitle;

  /// aiHealthTitle
  ///
  /// In en, this message translates to:
  /// **'AI System Health Report'**
  String get aiHealthTitle;

  /// aiHealthSubtitle
  ///
  /// In en, this message translates to:
  /// **'Intelligent diagnostic for your Arch Linux'**
  String get aiHealthSubtitle;

  /// aiCorrection
  ///
  /// In en, this message translates to:
  /// **'Did you mean?'**
  String get aiCorrection;

  /// aiThinking
  ///
  /// In en, this message translates to:
  /// **'AI is thinking...'**
  String get aiThinking;

  /// magicSearch
  ///
  /// In en, this message translates to:
  /// **'Magic Search'**
  String get magicSearch;

  /// aiChangelogTitle
  ///
  /// In en, this message translates to:
  /// **'AI Update Summary'**
  String get aiChangelogTitle;

  /// aiCliTitle
  ///
  /// In en, this message translates to:
  /// **'AI Command Generator'**
  String get aiCliTitle;

  /// aiConflictTitle
  ///
  /// In en, this message translates to:
  /// **'AI Conflict Detection'**
  String get aiConflictTitle;

  /// aiCopyCommand
  ///
  /// In en, this message translates to:
  /// **'Copy Command'**
  String get aiCopyCommand;

  /// aiCommandCopied
  ///
  /// In en, this message translates to:
  /// **'Command copied to clipboard'**
  String get aiCommandCopied;

  /// aiRefineSearch
  ///
  /// In en, this message translates to:
  /// **'Refine search with AI'**
  String get aiRefineSearch;

  /// aiExplainUpdate
  ///
  /// In en, this message translates to:
  /// **'Explain this update'**
  String get aiExplainUpdate;

  /// Tooltip for window minimize button
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get windowMinimize;

  /// Tooltip for window maximize button
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get windowMaximize;

  /// Tooltip for window restore button
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get windowRestore;

  /// Tooltip for window close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get windowClose;

  /// App Name
  ///
  /// In en, this message translates to:
  /// **'OmniStore'**
  String get omnistore;

  /// Title for the installed apps page
  ///
  /// In en, this message translates to:
  /// **'Installed Apps'**
  String get installedApps;

  /// Title for the GitHub store page
  ///
  /// In en, this message translates to:
  /// **'GitHub Store'**
  String get githubStore;

  /// Title for the Flatpak store page
  ///
  /// In en, this message translates to:
  /// **'Flatpak Store'**
  String get flatpakStore;

  /// Tooltip for locating the app installation folder
  ///
  /// In en, this message translates to:
  /// **'Locate Installation'**
  String get locateInstallation;

  /// Description for delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Description for welcomeTitle
  ///
  /// In en, this message translates to:
  /// **'Welcome to OmniStore'**
  String get welcomeTitle;

  /// Description for welcomeSubtitle
  ///
  /// In en, this message translates to:
  /// **'Providing a simple and elegant software management experience for Arch Linux'**
  String get welcomeSubtitle;

  /// Description for getStarted
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Description for skip
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Description for envCheckTitle
  ///
  /// In en, this message translates to:
  /// **'Environment Check'**
  String get envCheckTitle;

  /// Description for envCheckSubtitle
  ///
  /// In en, this message translates to:
  /// **'Ensuring your system is ready'**
  String get envCheckSubtitle;

  /// Description for envFatalDesc
  ///
  /// In en, this message translates to:
  /// **'Your system doesn\'t seem to be Arch-based. Most features will be unavailable.'**
  String get envFatalDesc;

  /// Description for envWarningDesc
  ///
  /// In en, this message translates to:
  /// **'Some necessary components are missing. We can configure them for you.'**
  String get envWarningDesc;

  /// Description for envOkDesc
  ///
  /// In en, this message translates to:
  /// **'Everything is ready! Your system is perfect.'**
  String get envOkDesc;

  /// Description for fixProblems
  ///
  /// In en, this message translates to:
  /// **'Fix / Configure All'**
  String get fixProblems;

  /// Description for continueAnyway
  ///
  /// In en, this message translates to:
  /// **'Continue Anyway'**
  String get continueAnyway;

  /// Description for sourceConfigTitle
  ///
  /// In en, this message translates to:
  /// **'Software Sources'**
  String get sourceConfigTitle;

  /// Description for sourceConfigSubtitle
  ///
  /// In en, this message translates to:
  /// **'Choose the sources you want to enable'**
  String get sourceConfigSubtitle;

  /// Description for enableAur
  ///
  /// In en, this message translates to:
  /// **'Enable AUR (Arch User Repository)'**
  String get enableAur;

  /// Description for yayDesc
  ///
  /// In en, this message translates to:
  /// **'Enabling AUR requires installing the yay helper.'**
  String get yayDesc;

  /// Description for aurWarning
  ///
  /// In en, this message translates to:
  /// **'Security Warning: AUR packages are user-contributed. Ensure you trust the source.'**
  String get aurWarning;

  /// Description for bootstrapNote
  ///
  /// In en, this message translates to:
  /// **'Note: Setup may require entering your password multiple times.'**
  String get bootstrapNote;

  /// Description for feedbackDesc
  ///
  /// In en, this message translates to:
  /// **'If you encounter issues, please report them on GitHub.'**
  String get feedbackDesc;

  /// Description for aiAssistant
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistant;

  /// Description for aiAssistantDesc
  ///
  /// In en, this message translates to:
  /// **'Enable AI-powered search, app explanation, and error diagnosis.'**
  String get aiAssistantDesc;

  /// Description for aiProviderDesc
  ///
  /// In en, this message translates to:
  /// **'Select your AI model source (Local or Cloud)'**
  String get aiProviderDesc;

  /// Description for aiEndpointHelper
  ///
  /// In en, this message translates to:
  /// **'Ollama defaults to http://localhost:11434'**
  String get aiEndpointHelper;

  /// Description for aiApiKeyHelper
  ///
  /// In en, this message translates to:
  /// **'Leave blank for Ollama, enter sk-xxx for OpenAI'**
  String get aiApiKeyHelper;

  /// Description for howToGetApiKey
  ///
  /// In en, this message translates to:
  /// **'How to get an API key?'**
  String get howToGetApiKey;

  /// Description for howToGetApiKeyDesc
  ///
  /// In en, this message translates to:
  /// **'1. Ollama (Local): Download and run Ollama, no key needed. 2. Cloud (OpenAI): Go to the provider\'s website, create an API Key, and enter it here.'**
  String get howToGetApiKeyDesc;

  /// Description for gotIt
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// Description for aiOllamaNote
  ///
  /// In en, this message translates to:
  /// **'Note: If using Ollama, ensure it\'s running with OLLAMA_ORIGINS=\"*\".'**
  String get aiOllamaNote;

  /// Description for enterStore
  ///
  /// In en, this message translates to:
  /// **'Enter Store'**
  String get enterStore;

  /// Description for nextStep
  ///
  /// In en, this message translates to:
  /// **'Next Step'**
  String get nextStep;

  /// Description for resetCache
  ///
  /// In en, this message translates to:
  /// **'Reset Cache and History'**
  String get resetCache;

  /// Description for resetCacheDesc
  ///
  /// In en, this message translates to:
  /// **'Clear search history and local recommendations cache'**
  String get resetCacheDesc;

  /// Description for resetCacheConfirm
  ///
  /// In en, this message translates to:
  /// **'This will clear your search history and recommendations cache. Proceed?'**
  String get resetCacheConfirm;

  /// Description for resetting
  ///
  /// In en, this message translates to:
  /// **'Resetting...'**
  String get resetting;

  /// Description for resetSuccess
  ///
  /// In en, this message translates to:
  /// **'Cache and History cleared successfully'**
  String get resetSuccess;

  /// No description provided for @resetFailed.
  ///
  /// In en, this message translates to:
  /// **'Reset failed: {error}'**
  String resetFailed(String error);

  /// Description for ollamaLocal
  ///
  /// In en, this message translates to:
  /// **'Ollama (Local)'**
  String get ollamaLocal;

  /// Description for openaiCompatible
  ///
  /// In en, this message translates to:
  /// **'OpenAI Compatible'**
  String get openaiCompatible;

  /// Description for googleGemini
  ///
  /// In en, this message translates to:
  /// **'Google Gemini'**
  String get googleGemini;

  /// Description for importPackages
  ///
  /// In en, this message translates to:
  /// **'Import Packages'**
  String get importPackages;

  /// No description provided for @importPackagesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Read {count} packages from file. Start batch download?'**
  String importPackagesConfirm(int count);

  /// Description for allDownloads
  ///
  /// In en, this message translates to:
  /// **'Download All'**
  String get allDownloads;

  /// Description for importList
  ///
  /// In en, this message translates to:
  /// **'Import List'**
  String get importList;

  /// Description for loadError
  ///
  /// In en, this message translates to:
  /// **'Failed to load recommendations, please check backend status'**
  String get loadError;

  /// Description for community
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// Description for official
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get official;

  /// Description for verified
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @installingPkg.
  ///
  /// In en, this message translates to:
  /// **'Installing {name}...'**
  String installingPkg(String name);

  /// Description for switchSource
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchSource;

  /// Description for flatpakBetterDesc
  ///
  /// In en, this message translates to:
  /// **'Found a Flatpak source for this app, which is usually more stable.'**
  String get flatpakBetterDesc;

  /// Description for aiAnalysisPrompt
  ///
  /// In en, this message translates to:
  /// **'Found error logs, do you need an AI analysis?'**
  String get aiAnalysisPrompt;

  /// Description for analyzeNow
  ///
  /// In en, this message translates to:
  /// **'Analyze Now'**
  String get analyzeNow;

  /// Description for cleanOrphans
  ///
  /// In en, this message translates to:
  /// **'Clean unused dependencies (orphans)'**
  String get cleanOrphans;

  /// Description for securityWarning
  ///
  /// In en, this message translates to:
  /// **'Security Warning'**
  String get securityWarning;

  /// Description for aurSecurityDesc
  ///
  /// In en, this message translates to:
  /// **'AUR (Arch User Repository) is a community-maintained repository. Since anyone can upload packages, there might be insecure code. Before installing, it is recommended to check the PKGBUILD.'**
  String get aurSecurityDesc;

  /// Description for continueInstall
  ///
  /// In en, this message translates to:
  /// **'Continue Install'**
  String get continueInstall;

  /// Description for installInfo
  ///
  /// In en, this message translates to:
  /// **'Installation Info'**
  String get installInfo;

  /// Description for downloadSize
  ///
  /// In en, this message translates to:
  /// **'Download Size'**
  String get downloadSize;

  /// Description for installedSize
  ///
  /// In en, this message translates to:
  /// **'Installed Size'**
  String get installedSize;

  /// No description provided for @dependenciesCount.
  ///
  /// In en, this message translates to:
  /// **'Dependencies ({count})'**
  String dependenciesCount(int count);

  /// Description for runningInBackground
  ///
  /// In en, this message translates to:
  /// **'OmniStore is running in the background, you can open it via the tray icon.'**
  String get runningInBackground;

  /// Description for clearSearch
  ///
  /// In en, this message translates to:
  /// **'Clear Search'**
  String get clearSearch;

  /// Description for listView
  ///
  /// In en, this message translates to:
  /// **'List View'**
  String get listView;

  /// Description for gridView
  ///
  /// In en, this message translates to:
  /// **'Grid View'**
  String get gridView;

  /// Description for categories
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// Description for clearHistory
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// Description for confirmClearHistory
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all history?'**
  String get confirmClearHistory;

  /// Description for viewMore
  ///
  /// In en, this message translates to:
  /// **'View More'**
  String get viewMore;

  /// Description for logDebug
  ///
  /// In en, this message translates to:
  /// **'DEBUG'**
  String get logDebug;

  /// Description for logInfo
  ///
  /// In en, this message translates to:
  /// **'INFO'**
  String get logInfo;

  /// Description for logWarning
  ///
  /// In en, this message translates to:
  /// **'WARNING'**
  String get logWarning;

  /// Description for logError
  ///
  /// In en, this message translates to:
  /// **'ERROR'**
  String get logError;

  /// Description for notificationTitle
  ///
  /// In en, this message translates to:
  /// **'Updates Available'**
  String get notificationTitle;

  /// No description provided for @notificationBody.
  ///
  /// In en, this message translates to:
  /// **'{count} applications are available for update'**
  String notificationBody(int count);

  /// Description for preparingUpdate
  ///
  /// In en, this message translates to:
  /// **'Preparing update...'**
  String get preparingUpdate;

  /// Description for processing
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// Description for clear
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Description for retry
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Message shown when AI fails to respond
  ///
  /// In en, this message translates to:
  /// **'AI failed to respond.'**
  String get aiResponseFailed;

  /// Message shown when AI fails to analyze error logs
  ///
  /// In en, this message translates to:
  /// **'AI failed to analyze.'**
  String get aiAnalysisFailed;

  /// Error message when backend is unreachable
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to backend service: {error}'**
  String cannotConnectToBackend(String error);

  /// Status message when a task is initializing
  ///
  /// In en, this message translates to:
  /// **'Initializing task...'**
  String get taskInitializing;

  /// Status message when a task is starting
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get taskStarting;

  /// Status message when a task completes successfully
  ///
  /// In en, this message translates to:
  /// **'Task completed successfully'**
  String get taskSuccess;

  /// Status message when a task fails with an exit code
  ///
  /// In en, this message translates to:
  /// **'Task failed with exit code {code}'**
  String taskFailedWithCode(int code);

  /// Status message when a task is cancelled by the user
  ///
  /// In en, this message translates to:
  /// **'Task cancelled by user'**
  String get taskCancelledByUser;

  /// Status message when a task encounters an error
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String taskError(String error);

  /// Title for GitHub auth page
  ///
  /// In en, this message translates to:
  /// **'GitHub Authentication'**
  String get githubAuthTitle;

  /// Success message for saving GitHub PAT
  ///
  /// In en, this message translates to:
  /// **'GitHub PAT saved successfully'**
  String get githubPatSaved;

  /// Button label to save token
  ///
  /// In en, this message translates to:
  /// **'Save Token'**
  String get saveToken;

  /// Back button label
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Next button label
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Label for advanced settings toggle
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// Section title for general settings
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// Section title for software repositories
  ///
  /// In en, this message translates to:
  /// **'Repositories'**
  String get repositories;

  /// Full name for AUR
  ///
  /// In en, this message translates to:
  /// **'AUR (Arch User Repository)'**
  String get aurFull;

  /// Full name for Flatpak
  ///
  /// In en, this message translates to:
  /// **'Flatpak (Flathub)'**
  String get flatpakFull;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
