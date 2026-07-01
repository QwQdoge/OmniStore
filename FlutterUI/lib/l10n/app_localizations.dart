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

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search apps, games, tools...'**
  String get searchHint;

  /// No description provided for @featured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featured;

  /// No description provided for @forYou.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get forYou;

  /// No description provided for @essentialTools.
  ///
  /// In en, this message translates to:
  /// **'Essential Tools'**
  String get essentialTools;

  /// No description provided for @hotApps.
  ///
  /// In en, this message translates to:
  /// **'Hot Apps'**
  String get hotApps;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @userAccount.
  ///
  /// In en, this message translates to:
  /// **'User Account'**
  String get userAccount;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @uninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get uninstall;

  /// No description provided for @launch.
  ///
  /// In en, this message translates to:
  /// **'Launch'**
  String get launch;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// Label for app variants/versions
  ///
  /// In en, this message translates to:
  /// **'Versions'**
  String get variant;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @resultsFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String resultsFound(int count);

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @searching.
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

  /// No description provided for @packageManager.
  ///
  /// In en, this message translates to:
  /// **'Package Manager'**
  String get packageManager;

  /// No description provided for @pacmanOfficial.
  ///
  /// In en, this message translates to:
  /// **'Pacman (Official)'**
  String get pacmanOfficial;

  /// No description provided for @aurUser.
  ///
  /// In en, this message translates to:
  /// **'AUR (User)'**
  String get aurUser;

  /// No description provided for @flatpak.
  ///
  /// In en, this message translates to:
  /// **'Flatpak'**
  String get flatpak;

  /// No description provided for @appImage.
  ///
  /// In en, this message translates to:
  /// **'AppImage'**
  String get appImage;

  /// No description provided for @sourcePriority.
  ///
  /// In en, this message translates to:
  /// **'Source Priority (Drag to reorder)'**
  String get sourcePriority;

  /// No description provided for @maxResults.
  ///
  /// In en, this message translates to:
  /// **'Max Results'**
  String get maxResults;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeColor.
  ///
  /// In en, this message translates to:
  /// **'Theme Color Seed'**
  String get themeColor;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get followSystem;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @loggingLevel.
  ///
  /// In en, this message translates to:
  /// **'Logging Level'**
  String get loggingLevel;

  /// No description provided for @saveAndApply.
  ///
  /// In en, this message translates to:
  /// **'Save and Apply'**
  String get saveAndApply;

  /// No description provided for @configSaved.
  ///
  /// In en, this message translates to:
  /// **'Configuration saved, some changes will take effect after restart'**
  String get configSaved;

  /// No description provided for @configSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save configuration'**
  String get configSaveFailed;

  /// No description provided for @confirmUninstall.
  ///
  /// In en, this message translates to:
  /// **'Confirm Uninstall'**
  String get confirmUninstall;

  /// No description provided for @confirmInstall.
  ///
  /// In en, this message translates to:
  /// **'Confirm Install'**
  String get confirmInstall;

  /// No description provided for @confirmActionMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to perform this action on {name}?'**
  String confirmActionMsg(String name);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @terminalOutput.
  ///
  /// In en, this message translates to:
  /// **'Terminal Output'**
  String get terminalOutput;

  /// No description provided for @waitingForOutput.
  ///
  /// In en, this message translates to:
  /// **'Waiting for output...'**
  String get waitingForOutput;

  /// No description provided for @screenshots.
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get screenshots;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @taskCancelled.
  ///
  /// In en, this message translates to:
  /// **'Task Cancelled'**
  String get taskCancelled;

  /// No description provided for @catDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Development'**
  String get catDevelopment;

  /// No description provided for @catMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get catMedia;

  /// No description provided for @catInternet.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get catInternet;

  /// No description provided for @catSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get catSystem;

  /// No description provided for @catOffice.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get catOffice;

  /// No description provided for @catGames.
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

  /// No description provided for @updates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updates;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'All apps are up to date'**
  String get upToDate;

  /// No description provided for @checkUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkUpdates;

  /// No description provided for @foundUpdates.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Found 1 update} other{Found {count} updates}}'**
  String foundUpdates(int count);

  /// No description provided for @updateAll.
  ///
  /// In en, this message translates to:
  /// **'Update All'**
  String get updateAll;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get enableNotifications;

  /// No description provided for @progressNotifications.
  ///
  /// In en, this message translates to:
  /// **'Progress Notifications'**
  String get progressNotifications;

  /// No description provided for @completionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Completion Notifications'**
  String get completionNotifications;

  /// No description provided for @closeToTray.
  ///
  /// In en, this message translates to:
  /// **'Close to system tray'**
  String get closeToTray;

  /// No description provided for @useSystemTitleBar.
  ///
  /// In en, this message translates to:
  /// **'Use system title bar'**
  String get useSystemTitleBar;

  /// No description provided for @showWindow.
  ///
  /// In en, this message translates to:
  /// **'Show Window'**
  String get showWindow;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @trayTooltipUpdates.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{OmniStore: Found 1 update} other{OmniStore: Found {count} updates}}'**
  String trayTooltipUpdates(int count);

  /// No description provided for @trayTooltipUpToDate.
  ///
  /// In en, this message translates to:
  /// **'OmniStore: Up to date'**
  String get trayTooltipUpToDate;

  /// No description provided for @updateReminders.
  ///
  /// In en, this message translates to:
  /// **'Update Reminders'**
  String get updateReminders;

  /// No description provided for @maintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenance;

  /// No description provided for @updateAllPackages.
  ///
  /// In en, this message translates to:
  /// **'Update All Packages'**
  String get updateAllPackages;

  /// No description provided for @includeAurUpdates.
  ///
  /// In en, this message translates to:
  /// **'Include AUR in \'Update All\''**
  String get includeAurUpdates;

  /// No description provided for @resetOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Reset Onboarding (Welcome Page)'**
  String get resetOnboarding;

  /// No description provided for @resetOnboardingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset onboarding? The welcome page will show on next launch.'**
  String get resetOnboardingConfirm;

  /// No description provided for @checkInterval.
  ///
  /// In en, this message translates to:
  /// **'Update Check Interval (Hours)'**
  String get checkInterval;

  /// No description provided for @remindMeOfUpdates.
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

  /// No description provided for @installSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Installation Successful'**
  String get installSuccessTitle;

  /// No description provided for @uninstallSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Uninstallation Successful'**
  String get uninstallSuccessTitle;

  /// No description provided for @installFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Installation Failed'**
  String get installFailedTitle;

  /// No description provided for @uninstallFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Uninstallation Failed'**
  String get uninstallFailedTitle;

  /// No description provided for @taskCompleted.
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

  /// systemCleaningDesc
  ///
  /// In en, this message translates to:
  /// **'Delete orphan packages and clean pacman cache'**
  String get systemCleaningDesc;

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
  /// **'{count, plural, =1{Export successful: 1 package} other{Export successful: {count} packages}}'**
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
  /// **'{count, plural, =1{Read 1 package from backup. Start recovery?} other{Read {count} packages from backup. Start batch recovery?}}'**
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

  /// Section title for general settings
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// Label for advanced settings toggle
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// Section title for software repositories
  ///
  /// In en, this message translates to:
  /// **'Repositories'**
  String get repositories;

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

  /// aiEnabledDesc
  ///
  /// In en, this message translates to:
  /// **'Enable AI-powered search, app explanation, and error diagnosis.'**
  String get aiEnabledDesc;

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

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to OmniStore'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Providing a simple and elegant software management experience for Arch Linux'**
  String get welcomeSubtitle;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @envCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Environment Check'**
  String get envCheckTitle;

  /// No description provided for @envCheckSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ensuring your system is ready'**
  String get envCheckSubtitle;

  /// No description provided for @envFatalDesc.
  ///
  /// In en, this message translates to:
  /// **'Your system doesn\'t seem to be Arch-based. Most features will be unavailable.'**
  String get envFatalDesc;

  /// No description provided for @envWarningDesc.
  ///
  /// In en, this message translates to:
  /// **'Some necessary components are missing. We can configure them for you.'**
  String get envWarningDesc;

  /// No description provided for @envOkDesc.
  ///
  /// In en, this message translates to:
  /// **'Everything is ready! Your system is perfect.'**
  String get envOkDesc;

  /// No description provided for @fixProblems.
  ///
  /// In en, this message translates to:
  /// **'Fix / Configure All'**
  String get fixProblems;

  /// No description provided for @continueAnyway.
  ///
  /// In en, this message translates to:
  /// **'Continue Anyway'**
  String get continueAnyway;

  /// No description provided for @sourceConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Software Sources'**
  String get sourceConfigTitle;

  /// No description provided for @sourceConfigSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the sources you want to enable'**
  String get sourceConfigSubtitle;

  /// No description provided for @enableAur.
  ///
  /// In en, this message translates to:
  /// **'Enable AUR (Arch User Repository)'**
  String get enableAur;

  /// No description provided for @yayDesc.
  ///
  /// In en, this message translates to:
  /// **'Enabling AUR requires installing the yay helper.'**
  String get yayDesc;

  /// No description provided for @aurWarning.
  ///
  /// In en, this message translates to:
  /// **'Security Warning: AUR packages are user-contributed. Ensure you trust the source.'**
  String get aurWarning;

  /// No description provided for @bootstrapNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Setup may require entering your password multiple times.'**
  String get bootstrapNote;

  /// No description provided for @feedbackDesc.
  ///
  /// In en, this message translates to:
  /// **'If you encounter issues, please report them on GitHub.'**
  String get feedbackDesc;

  /// No description provided for @aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistant;

  /// No description provided for @aiAssistantDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable AI-powered search, app explanation, and error diagnosis.'**
  String get aiAssistantDesc;

  /// No description provided for @aiProviderDesc.
  ///
  /// In en, this message translates to:
  /// **'Select your AI model source (Local or Cloud)'**
  String get aiProviderDesc;

  /// No description provided for @aiEndpointHelper.
  ///
  /// In en, this message translates to:
  /// **'Ollama defaults to http://localhost:11434'**
  String get aiEndpointHelper;

  /// No description provided for @aiApiKeyHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave blank for Ollama, enter sk-xxx for OpenAI'**
  String get aiApiKeyHelper;

  /// No description provided for @howToGetApiKey.
  ///
  /// In en, this message translates to:
  /// **'How to get an API key?'**
  String get howToGetApiKey;

  /// No description provided for @howToGetApiKeyDesc.
  ///
  /// In en, this message translates to:
  /// **'1. Ollama (Local): Download and run Ollama, no key needed. 2. Cloud (OpenAI): Go to the provider\'s website, create an API Key, and enter it here.'**
  String get howToGetApiKeyDesc;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @aiOllamaNote.
  ///
  /// In en, this message translates to:
  /// **'Note: If using Ollama, ensure it\'s running with OLLAMA_ORIGINS=\"*\".'**
  String get aiOllamaNote;

  /// No description provided for @enterStore.
  ///
  /// In en, this message translates to:
  /// **'Enter Store'**
  String get enterStore;

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'Next Step'**
  String get nextStep;

  /// No description provided for @resetCache.
  ///
  /// In en, this message translates to:
  /// **'Reset Cache and History'**
  String get resetCache;

  /// No description provided for @resetCacheDesc.
  ///
  /// In en, this message translates to:
  /// **'Clear search history and local recommendations cache'**
  String get resetCacheDesc;

  /// No description provided for @resetCacheConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will clear your search history and recommendations cache. Proceed?'**
  String get resetCacheConfirm;

  /// No description provided for @resetting.
  ///
  /// In en, this message translates to:
  /// **'Resetting...'**
  String get resetting;

  /// No description provided for @resetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cache and History cleared successfully'**
  String get resetSuccess;

  /// No description provided for @resetFailed.
  ///
  /// In en, this message translates to:
  /// **'Reset failed: {error}'**
  String resetFailed(String error);

  /// No description provided for @ollamaLocal.
  ///
  /// In en, this message translates to:
  /// **'Ollama (Local)'**
  String get ollamaLocal;

  /// No description provided for @openaiCompatible.
  ///
  /// In en, this message translates to:
  /// **'OpenAI Compatible'**
  String get openaiCompatible;

  /// No description provided for @googleGemini.
  ///
  /// In en, this message translates to:
  /// **'Google Gemini'**
  String get googleGemini;

  /// No description provided for @importPackages.
  ///
  /// In en, this message translates to:
  /// **'Import Packages'**
  String get importPackages;

  /// No description provided for @importPackagesConfirm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Read 1 package from file. Start download?} other{Read {count} packages from file. Start batch download?}}'**
  String importPackagesConfirm(int count);

  /// No description provided for @allDownloads.
  ///
  /// In en, this message translates to:
  /// **'Download All'**
  String get allDownloads;

  /// No description provided for @importList.
  ///
  /// In en, this message translates to:
  /// **'Import List'**
  String get importList;

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load recommendations, please check backend status'**
  String get loadError;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @official.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get official;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @installingPkg.
  ///
  /// In en, this message translates to:
  /// **'Installing {name}...'**
  String installingPkg(String name);

  /// No description provided for @switchSource.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchSource;

  /// No description provided for @flatpakBetterDesc.
  ///
  /// In en, this message translates to:
  /// **'Found a Flatpak source for this app, which is usually more stable.'**
  String get flatpakBetterDesc;

  /// No description provided for @aiAnalysisPrompt.
  ///
  /// In en, this message translates to:
  /// **'Found error logs, do you need an AI analysis?'**
  String get aiAnalysisPrompt;

  /// No description provided for @analyzeNow.
  ///
  /// In en, this message translates to:
  /// **'Analyze Now'**
  String get analyzeNow;

  /// No description provided for @cleanOrphans.
  ///
  /// In en, this message translates to:
  /// **'Clean unused dependencies (orphans)'**
  String get cleanOrphans;

  /// No description provided for @securityWarning.
  ///
  /// In en, this message translates to:
  /// **'Security Warning'**
  String get securityWarning;

  /// No description provided for @aurSecurityDesc.
  ///
  /// In en, this message translates to:
  /// **'AUR (Arch User Repository) is a community-maintained repository. Since anyone can upload packages, there might be insecure code. Before installing, it is recommended to check the PKGBUILD.'**
  String get aurSecurityDesc;

  /// No description provided for @continueInstall.
  ///
  /// In en, this message translates to:
  /// **'Continue Install'**
  String get continueInstall;

  /// No description provided for @installInfo.
  ///
  /// In en, this message translates to:
  /// **'Installation Info'**
  String get installInfo;

  /// No description provided for @downloadSize.
  ///
  /// In en, this message translates to:
  /// **'Download Size'**
  String get downloadSize;

  /// No description provided for @installedSize.
  ///
  /// In en, this message translates to:
  /// **'Installed Size'**
  String get installedSize;

  /// No description provided for @dependenciesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Dependency (1)} other{Dependencies ({count})}}'**
  String dependenciesCount(int count);

  /// No description provided for @runningInBackground.
  ///
  /// In en, this message translates to:
  /// **'OmniStore is running in the background, you can open it via the tray icon.'**
  String get runningInBackground;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear Search'**
  String get clearSearch;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List View'**
  String get listView;

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid View'**
  String get gridView;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// No description provided for @clearHistoryShort.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistoryShort;

  /// No description provided for @confirmClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all history?'**
  String get confirmClearHistory;

  /// No description provided for @viewMore.
  ///
  /// In en, this message translates to:
  /// **'View More'**
  String get viewMore;

  /// No description provided for @logDebug.
  ///
  /// In en, this message translates to:
  /// **'DEBUG'**
  String get logDebug;

  /// No description provided for @logInfo.
  ///
  /// In en, this message translates to:
  /// **'INFO'**
  String get logInfo;

  /// No description provided for @logWarning.
  ///
  /// In en, this message translates to:
  /// **'WARNING'**
  String get logWarning;

  /// No description provided for @logError.
  ///
  /// In en, this message translates to:
  /// **'ERROR'**
  String get logError;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Updates Available'**
  String get notificationTitle;

  /// No description provided for @notificationBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 application is available for update} other{{count} applications are available for update}}'**
  String notificationBody(int count);

  /// No description provided for @preparingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Preparing update...'**
  String get preparingUpdate;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @retry.
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

  /// No description provided for @errorPackageNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Error: Package name cannot be empty'**
  String get errorPackageNameRequired;

  /// No description provided for @errorStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start: {error}'**
  String errorStartFailed(String error);

  /// No description provided for @errorUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String errorUpdateFailed(String error);

  /// No description provided for @checkUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Check update failed: {error}'**
  String checkUpdateFailed(String error);

  /// No description provided for @errorCleanFailed.
  ///
  /// In en, this message translates to:
  /// **'Cleanup failed: {error}'**
  String errorCleanFailed(String error);

  /// No description provided for @errorFatalStream.
  ///
  /// In en, this message translates to:
  /// **'Fatal data stream error: {error}'**
  String errorFatalStream(String error);

  /// No description provided for @errorProcessStart.
  ///
  /// In en, this message translates to:
  /// **'Process start failed, please check environment: {error}'**
  String errorProcessStart(String error);

  /// Error message when a task is forcefully terminated
  ///
  /// In en, this message translates to:
  /// **'Task forcibly terminated'**
  String get taskForcedTerminated;

  /// Error message when AI request times out
  ///
  /// In en, this message translates to:
  /// **'AI connection timed out, please try again later.'**
  String get aiTimeout;

  /// Error message when AI does not respond
  ///
  /// In en, this message translates to:
  /// **'AI failed to provide a valid response.'**
  String get aiNoResponse;

  /// Error message when AI response parsing fails
  ///
  /// In en, this message translates to:
  /// **'AI response parsing failed: incorrect format.'**
  String get aiParseFailed;

  /// No description provided for @aiCallFailed.
  ///
  /// In en, this message translates to:
  /// **'AI service call failed: {error}'**
  String aiCallFailed(String error);

  /// No description provided for @errorUpdateAll.
  ///
  /// In en, this message translates to:
  /// **'Update all error: {error}'**
  String errorUpdateAll(String error);

  /// Task processing status label
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get taskProcessing;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @relatedApps.
  ///
  /// In en, this message translates to:
  /// **'Related Apps'**
  String get relatedApps;

  /// Label for active software sources
  ///
  /// In en, this message translates to:
  /// **'Active Sources'**
  String get activeSources;

  /// Button to auto detect available sources
  ///
  /// In en, this message translates to:
  /// **'Auto Detect'**
  String get autoDetect;

  /// Button to add a custom source
  ///
  /// In en, this message translates to:
  /// **'Add Custom Source'**
  String get addCustomSource;

  /// No description provided for @addCustomSourceDesc.
  ///
  /// In en, this message translates to:
  /// **'Configure custom Flatpak remotes, AppImage feeds, or GitHub/Bitu repos'**
  String get addCustomSourceDesc;

  /// Label for source type
  ///
  /// In en, this message translates to:
  /// **'Source Type'**
  String get sourceType;

  /// GitHub source type option
  ///
  /// In en, this message translates to:
  /// **'GitHub Repository (owner/repo)'**
  String get githubRepoType;

  /// Bitu source type option
  ///
  /// In en, this message translates to:
  /// **'Bitu / Bitbucket (workspace/repo)'**
  String get bituRepoType;

  /// Flatpak source type option
  ///
  /// In en, this message translates to:
  /// **'Flatpak Remote'**
  String get flatpakRemoteType;

  /// AppImage source type option
  ///
  /// In en, this message translates to:
  /// **'AppImage Feed URL'**
  String get appImageFeedType;

  /// Label for source name
  ///
  /// In en, this message translates to:
  /// **'Source Name'**
  String get sourceName;

  /// Hint for custom app name
  ///
  /// In en, this message translates to:
  /// **'e.g. my-custom-app'**
  String get hintCustomAppName;

  /// Label for repository owner and name
  ///
  /// In en, this message translates to:
  /// **'Repository (owner/repo)'**
  String get repoOwnerRepo;

  /// Label for source URL
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get sourceUrl;

  /// Hint for repository format
  ///
  /// In en, this message translates to:
  /// **'e.g. flutter/flutter'**
  String get hintRepoFormat;

  /// Hint for feed URL
  ///
  /// In en, this message translates to:
  /// **'e.g. https://example.com/feed.json'**
  String get hintFeedUrl;

  /// Error message when name or URL is missing
  ///
  /// In en, this message translates to:
  /// **'Name and URL/Repo cannot be empty'**
  String get errorNameUrlRequired;

  /// Message while adding custom source
  ///
  /// In en, this message translates to:
  /// **'Adding custom source...'**
  String get addingCustomSource;

  /// Success message after adding source
  ///
  /// In en, this message translates to:
  /// **'Source added successfully!'**
  String get sourceAddSuccess;

  /// Failure message after adding source
  ///
  /// In en, this message translates to:
  /// **'Failed to add source.'**
  String get sourceAddFailed;

  /// Message while auto detecting sources
  ///
  /// In en, this message translates to:
  /// **'Auto-detecting available sources for your system...'**
  String get autoDetectingSources;

  /// Success message after auto detection
  ///
  /// In en, this message translates to:
  /// **'Auto-detection complete and settings saved!'**
  String get autoDetectSuccess;

  /// Failure message after auto detection
  ///
  /// In en, this message translates to:
  /// **'Failed to save auto-detected settings.'**
  String get autoDetectFailed;

  /// Label for personal access token
  ///
  /// In en, this message translates to:
  /// **'Personal Access Token'**
  String get personalAccessToken;

  /// Button to copy the package name
  ///
  /// In en, this message translates to:
  /// **'Copy Name'**
  String get copyName;

  /// Snackbar message indicating name was copied to clipboard
  ///
  /// In en, this message translates to:
  /// **'Name copied to clipboard'**
  String get nameCopied;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @tapToCopy.
  ///
  /// In en, this message translates to:
  /// **'Tap to copy'**
  String get tapToCopy;

  /// Label for language setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Subtitle for language setting
  ///
  /// In en, this message translates to:
  /// **'Requires restart to take effect'**
  String get languageSubtitle;

  /// Message to restart for title bar changes
  ///
  /// In en, this message translates to:
  /// **'Please restart to apply title bar changes'**
  String get restartTitleBar;

  /// Label for background daemon
  ///
  /// In en, this message translates to:
  /// **'Enable Background Update Daemon'**
  String get enableDaemon;

  /// No description provided for @enableDaemonDesc.
  ///
  /// In en, this message translates to:
  /// **'Regularly check for updates in the background'**
  String get enableDaemonDesc;

  /// Label for auto update
  ///
  /// In en, this message translates to:
  /// **'Silent Auto Update'**
  String get autoUpdate;

  /// No description provided for @autoUpdateDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically download and update all packages in the background'**
  String get autoUpdateDesc;

  /// Title for update check interval
  ///
  /// In en, this message translates to:
  /// **'Update Check Frequency'**
  String get checkIntervalTitle;

  /// No description provided for @checkIntervalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{Automatically check every hour} other{Automatically check every {hours} hours}}'**
  String checkIntervalSubtitle(int hours);

  /// Title for typography settings
  ///
  /// In en, this message translates to:
  /// **'Typography'**
  String get typography;

  /// Label for font family setting
  ///
  /// In en, this message translates to:
  /// **'Font Family'**
  String get fontFamily;

  /// Label for font scale setting
  ///
  /// In en, this message translates to:
  /// **'Font Scale'**
  String get fontScale;

  /// Label for system default option
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @hourValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String hourValue(int count);

  /// No description provided for @langSimplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get langSimplifiedChinese;

  /// No description provided for @langTraditionalChinese.
  ///
  /// In en, this message translates to:
  /// **'Traditional Chinese'**
  String get langTraditionalChinese;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get langJapanese;

  /// No description provided for @langSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get langSpanish;

  /// Error message when trying to start a task while another is running
  ///
  /// In en, this message translates to:
  /// **'Another task is already in progress'**
  String get taskInProgress;

  /// Error message when system tray fails to initialize
  ///
  /// In en, this message translates to:
  /// **'System tray initialization failed. Close to tray disabled.'**
  String get trayInitFailedDisabled;

  /// General error title
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorTitle;

  /// Message shown when app details cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'App details not found'**
  String get appDetailsNotFound;

  /// No description provided for @diskSpaceInfo.
  ///
  /// In en, this message translates to:
  /// **'Disk Space: {free} GB free / {total} GB total'**
  String diskSpaceInfo(String free, String total);

  /// No description provided for @cacheTypeInfo.
  ///
  /// In en, this message translates to:
  /// **'Pacman: {pacman} MB | Flatpak: {flatpak} MB | Custom: {custom} MB'**
  String cacheTypeInfo(String pacman, String flatpak, String custom);

  /// Accessibility label for back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backSemanticsLabel;

  /// Accessibility hint for back button
  ///
  /// In en, this message translates to:
  /// **'Go back to the previous screen'**
  String get backSemanticsHint;

  /// No description provided for @categorySemantics.
  ///
  /// In en, this message translates to:
  /// **'Category: {name}'**
  String categorySemantics(String name);

  /// Error message for invalid temperature value
  ///
  /// In en, this message translates to:
  /// **'Value must be between 0.0 and 2.0'**
  String get temperatureRangeError;

  /// No description provided for @enableSystemdService.
  ///
  /// In en, this message translates to:
  /// **'Enable systemd Background Service'**
  String get enableSystemdService;

  /// No description provided for @enableSystemdServiceDesc.
  ///
  /// In en, this message translates to:
  /// **'Allow registering systemd timer to check for updates when the app is closed'**
  String get enableSystemdServiceDesc;

  /// No description provided for @taskHistory.
  ///
  /// In en, this message translates to:
  /// **'Task History'**
  String get taskHistory;

  /// No description provided for @unknownApp.
  ///
  /// In en, this message translates to:
  /// **'Unknown App'**
  String get unknownApp;

  /// No description provided for @taskSuccessMsg.
  ///
  /// In en, this message translates to:
  /// **'Task executed successfully'**
  String get taskSuccessMsg;

  /// No description provided for @failureReason.
  ///
  /// In en, this message translates to:
  /// **'Failure reason: {message}'**
  String failureReason(String message);

  /// No description provided for @noPackagesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No packages available'**
  String get noPackagesAvailable;

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'No description provided.'**
  String get noDescription;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @checkNetwork.
  ///
  /// In en, this message translates to:
  /// **'Check your network connection and try again'**
  String get checkNetwork;

  /// No description provided for @githubStoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover and download apps directly from GitHub releases'**
  String get githubStoreSubtitle;

  /// No description provided for @searchGithubHint.
  ///
  /// In en, this message translates to:
  /// **'Search GitHub repositories...'**
  String get searchGithubHint;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @rankings.
  ///
  /// In en, this message translates to:
  /// **'Rankings'**
  String get rankings;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @latestUpdates.
  ///
  /// In en, this message translates to:
  /// **'Latest Updates'**
  String get latestUpdates;

  /// No description provided for @searchNoResultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try searching for something else'**
  String get searchNoResultsSubtitle;
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
