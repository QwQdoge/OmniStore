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
  /// **'Activity & Updates'**
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

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

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
  /// **'Variants'**
  String get variant;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
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

  /// Explains when Pacman operations require authorization
  ///
  /// In en, this message translates to:
  /// **'Browsing, searching, viewing details, and checking Pacman updates never require account or administrator authorization. Authorization is requested only when the system is changed.'**
  String get pacmanBrowsingNoAuthorization;

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
  /// **'No active or completed tasks'**
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
  /// **'No package updates found'**
  String get allUpdated;

  /// update
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @updatingSourcePackages.
  ///
  /// In en, this message translates to:
  /// **'Updating {source} packages…'**
  String updatingSourcePackages(String source);

  /// No description provided for @sourceUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'{source} update failed'**
  String sourceUpdateFailed(String source);

  /// No description provided for @enabledSourcesUpdated.
  ///
  /// In en, this message translates to:
  /// **'All enabled package sources are up to date'**
  String get enabledSourcesUpdated;

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

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @clean.
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get clean;

  /// systemCleaningDesc
  ///
  /// In en, this message translates to:
  /// **'Remove orphan packages and clear the Pacman cache (administrator authorization required)'**
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
  /// **'Network proxy'**
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
  /// **'Choose where OmniStore may search for software'**
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
  /// **'Browsing never requires authorization. Administrator authorization is requested only when setup changes the system.'**
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

  /// Explanation shown when a package search fails
  ///
  /// In en, this message translates to:
  /// **'The software sources could not be reached. Check your connection and try again.'**
  String get searchFailedSubtitle;

  /// Number of capabilities exposed by a source plugin
  ///
  /// In en, this message translates to:
  /// **'{count} capabilities'**
  String pluginCapabilities(int count);

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
  /// **'Configure custom Pacman/Flatpak repositories, AppImage feeds, or GitHub/Bitu sources'**
  String get addCustomSourceDesc;

  /// No description provided for @pacmanRepoType.
  ///
  /// In en, this message translates to:
  /// **'Pacman repository'**
  String get pacmanRepoType;

  /// No description provided for @pacmanRepoSafety.
  ///
  /// In en, this message translates to:
  /// **'Only HTTPS repositories with required package signatures are accepted. OmniStore never downloads signing keys or runs pacman -Sy. The source takes effect during the next full system upgrade.'**
  String get pacmanRepoSafety;

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
  /// **'Completed successfully'**
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
  /// **'Try another keyword or enable more software sources'**
  String get searchNoResultsSubtitle;

  /// Section title for plugins and software sources
  ///
  /// In en, this message translates to:
  /// **'Plugins & Sources'**
  String get pluginsAndSources;

  /// Tooltip for refreshing plugin list
  ///
  /// In en, this message translates to:
  /// **'Refresh plugins'**
  String get refreshPlugins;

  /// Message shown when no source plugins are available
  ///
  /// In en, this message translates to:
  /// **'No source plugins found'**
  String get noPluginsFound;

  /// Label for builtin plugins
  ///
  /// In en, this message translates to:
  /// **'Builtin'**
  String get builtin;

  /// Label for legacy plugins
  ///
  /// In en, this message translates to:
  /// **'Legacy'**
  String get legacy;

  /// Success message after updating a plugin
  ///
  /// In en, this message translates to:
  /// **'Plugin updated'**
  String get pluginUpdated;

  /// Error message when plugin update fails
  ///
  /// In en, this message translates to:
  /// **'Plugin update failed'**
  String get pluginUpdateFailed;

  /// Success message after removing a plugin
  ///
  /// In en, this message translates to:
  /// **'Plugin removed'**
  String get pluginRemoved;

  /// Error message when plugin removal fails
  ///
  /// In en, this message translates to:
  /// **'Plugin removal failed'**
  String get pluginRemovalFailed;

  /// Tooltip for removing a plugin
  ///
  /// In en, this message translates to:
  /// **'Remove plugin'**
  String get removePlugin;

  /// No description provided for @managed.
  ///
  /// In en, this message translates to:
  /// **'Managed'**
  String get managed;

  /// No description provided for @readOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get readOnly;

  /// Description for installationDecisionTitle
  ///
  /// In en, this message translates to:
  /// **'Installation Decision Helper'**
  String get installationDecisionTitle;

  /// No description provided for @recommendedSource.
  ///
  /// In en, this message translates to:
  /// **'Recommended Source: {source}'**
  String recommendedSource(String source);

  /// Description for preflightChecks
  ///
  /// In en, this message translates to:
  /// **'Preflight Checks'**
  String get preflightChecks;

  /// Description for potentialRisks
  ///
  /// In en, this message translates to:
  /// **'Potential Risks'**
  String get potentialRisks;

  /// Description for continueInstallation
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueInstallation;

  /// Label for changing AI recommendation
  ///
  /// In en, this message translates to:
  /// **'Change recommendation'**
  String get changeRecommendation;

  /// Disclaimer for AI recommendations
  ///
  /// In en, this message translates to:
  /// **'Generated based on your search, installation history, and currently available sources; will not affect your installation choices.'**
  String get aiPickDisclaimer;

  /// Label for Quick Start section
  ///
  /// In en, this message translates to:
  /// **'Quick Start'**
  String get quickStart;

  /// Subtitle for importing packages from a list
  ///
  /// In en, this message translates to:
  /// **'Import your frequently used packages from a list'**
  String get importListSubtitle;

  /// Message shown when trending section is empty
  ///
  /// In en, this message translates to:
  /// **'No trending data available; it will automatically update when connection is restored.'**
  String get emptyTrendingMessage;

  /// Message shown when recommendations section is empty
  ///
  /// In en, this message translates to:
  /// **'Personalized suggestions will appear here after you search or install apps.'**
  String get emptyRecommendationsMessage;

  /// Fallback message shown when AI recommendation fails to generate
  ///
  /// In en, this message translates to:
  /// **'Unable to generate personalized recommendations at this time. You can still browse editor picks or try again later.'**
  String get aiPickFallbackMessage;

  /// Description for meoarchAccount
  ///
  /// In en, this message translates to:
  /// **'MeoArch Account'**
  String get meoarchAccount;

  /// Description for defaultUser
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get defaultUser;

  /// Description for signOut
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Description for syncStatus
  ///
  /// In en, this message translates to:
  /// **'Sync Status'**
  String get syncStatus;

  /// Description for syncStatusSubtitle
  ///
  /// In en, this message translates to:
  /// **'Tap to back up your OmniStore app list'**
  String get syncStatusSubtitle;

  /// Description for manageAccount
  ///
  /// In en, this message translates to:
  /// **'Manage Account'**
  String get manageAccount;

  /// Description for manageAccountSubtitle
  ///
  /// In en, this message translates to:
  /// **'Security, MFA, and sessions'**
  String get manageAccountSubtitle;

  /// Description for signInTitle
  ///
  /// In en, this message translates to:
  /// **'Sign In to MeoArch'**
  String get signInTitle;

  /// Description for signInSubtitle
  ///
  /// In en, this message translates to:
  /// **'Sync your apps, settings, and favorites across devices.'**
  String get signInSubtitle;

  /// Description for email
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Description for password
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Tooltip for showing password in plain text
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// Tooltip for hiding password in obscure text
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// Description for signIn
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// Description for createAccount
  ///
  /// In en, this message translates to:
  /// **'Create MeoArch Account'**
  String get createAccount;

  /// Description for orDivider
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orDivider;

  /// Description for continueWithGoogle
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// Description for continueWithGitHub
  ///
  /// In en, this message translates to:
  /// **'Continue with GitHub'**
  String get continueWithGitHub;

  /// Description for enterEmailAndPassword
  ///
  /// In en, this message translates to:
  /// **'Please enter email and password.'**
  String get enterEmailAndPassword;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed: {message}'**
  String signInFailed(String message);

  /// No description provided for @signInError.
  ///
  /// In en, this message translates to:
  /// **'Sign in error: {message}'**
  String signInError(String message);

  /// Description for githubIntegration
  ///
  /// In en, this message translates to:
  /// **'GitHub Integration'**
  String get githubIntegration;

  /// Description for configurePat
  ///
  /// In en, this message translates to:
  /// **'GitHub access token'**
  String get configurePat;

  /// Description for patHelperText
  ///
  /// In en, this message translates to:
  /// **'Add a GitHub Classic PAT or fine-grained token when you need authenticated GitHub access.'**
  String get patHelperText;

  /// Description for featuredSubtitle
  ///
  /// In en, this message translates to:
  /// **'Maintained by OmniStore, available even offline'**
  String get featuredSubtitle;

  /// Description for editorPicks
  ///
  /// In en, this message translates to:
  /// **'Editor\'s Choice'**
  String get editorPicks;

  /// Description for checkingEnvStatus
  ///
  /// In en, this message translates to:
  /// **'Checking environment status...'**
  String get checkingEnvStatus;

  /// Description for envDetailsFailed
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch environment details.'**
  String get envDetailsFailed;

  /// Description for bootstrapProgress
  ///
  /// In en, this message translates to:
  /// **'Bootstrap progress:'**
  String get bootstrapProgress;

  /// Description for systemDetails
  ///
  /// In en, this message translates to:
  /// **'System details:'**
  String get systemDetails;

  /// Description for aiIntegrationDesc
  ///
  /// In en, this message translates to:
  /// **'Enable intelligence integration features'**
  String get aiIntegrationDesc;

  /// Description for ollamaLocalOffline
  ///
  /// In en, this message translates to:
  /// **'Ollama (Local / Offline)'**
  String get ollamaLocalOffline;

  /// Description for openaiCloud
  ///
  /// In en, this message translates to:
  /// **'OpenAI API (Cloud)'**
  String get openaiCloud;

  /// Description for testConnection
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// Description for githubSearchFailed
  ///
  /// In en, this message translates to:
  /// **'GitHub search failed'**
  String get githubSearchFailed;

  /// Description for githubStoreUnavailable
  ///
  /// In en, this message translates to:
  /// **'GitHub Store unavailable'**
  String get githubStoreUnavailable;

  /// Description for noGithubReposFound
  ///
  /// In en, this message translates to:
  /// **'No GitHub repositories found'**
  String get noGithubReposFound;

  /// Description for pullToRefreshCategory
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh or try another category.'**
  String get pullToRefreshCategory;

  /// No description provided for @systemAiProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'System AI connection (KWallet / Recommended)'**
  String get systemAiProviderLabel;

  /// No description provided for @systemAiSharedConnectionLabel.
  ///
  /// In en, this message translates to:
  /// **'System shared connection'**
  String get systemAiSharedConnectionLabel;

  /// No description provided for @systemAiConnectionHelper.
  ///
  /// In en, this message translates to:
  /// **'Meo Account reads the key from KWallet; OmniStore cannot read the plaintext.'**
  String get systemAiConnectionHelper;

  /// No description provided for @systemAiLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading system AI connections'**
  String get systemAiLoadingTitle;

  /// No description provided for @systemAiMetadataOnly.
  ///
  /// In en, this message translates to:
  /// **'Only names, endpoints, and default models are read; keys are never read.'**
  String get systemAiMetadataOnly;

  /// No description provided for @systemAiLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to read system AI connections'**
  String get systemAiLoadErrorTitle;

  /// No description provided for @systemAiSelectLabel.
  ///
  /// In en, this message translates to:
  /// **'AI connection on this device'**
  String get systemAiSelectLabel;

  /// No description provided for @meoSettingsOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open Meo Settings.'**
  String get meoSettingsOpenFailed;

  /// No description provided for @manageInMeoSettings.
  ///
  /// In en, this message translates to:
  /// **'Manage in Meo Settings'**
  String get manageInMeoSettings;

  /// No description provided for @systemAiNoConnections.
  ///
  /// In en, this message translates to:
  /// **'No system AI connection is configured. Add one in Meo Settings first.'**
  String get systemAiNoConnections;

  /// No description provided for @systemAiLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read system AI connections. Check Accounts & Security in Meo Settings.'**
  String get systemAiLoadFailed;

  /// No description provided for @systemAiInvalidCatalog.
  ///
  /// In en, this message translates to:
  /// **'The system AI service returned an invalid model catalog.'**
  String get systemAiInvalidCatalog;

  /// No description provided for @systemAiInvalidConsent.
  ///
  /// In en, this message translates to:
  /// **'The system AI service did not return a valid consent summary.'**
  String get systemAiInvalidConsent;

  /// No description provided for @systemAiConsentExpired.
  ///
  /// In en, this message translates to:
  /// **'The system AI consent summary is invalid or expired.'**
  String get systemAiConsentExpired;

  /// No description provided for @systemAiInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The system AI service did not return valid text.'**
  String get systemAiInvalidResponse;

  /// No description provided for @systemAiUnsupported.
  ///
  /// In en, this message translates to:
  /// **'System AI is not supported on this platform.'**
  String get systemAiUnsupported;

  /// No description provided for @systemAiOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'The system AI operation failed.'**
  String get systemAiOperationFailed;

  /// No description provided for @systemAiTimeout.
  ///
  /// In en, this message translates to:
  /// **'The system AI operation timed out.'**
  String get systemAiTimeout;

  /// No description provided for @systemAiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the Meo Account system AI service.'**
  String get systemAiUnavailable;

  /// No description provided for @systemAiTestPurpose.
  ///
  /// In en, this message translates to:
  /// **'Test the OmniStore system AI connection'**
  String get systemAiTestPurpose;

  /// No description provided for @aiConsentCancelled.
  ///
  /// In en, this message translates to:
  /// **'You cancelled this AI request.'**
  String get aiConsentCancelled;

  /// No description provided for @chooseSystemAiConnection.
  ///
  /// In en, this message translates to:
  /// **'Select a system AI connection in OmniStore Settings first.'**
  String get chooseSystemAiConnection;

  /// No description provided for @chooseAccountAiConnection.
  ///
  /// In en, this message translates to:
  /// **'Select an account AI connection in OmniStore Settings first.'**
  String get chooseAccountAiConnection;

  /// No description provided for @aiConfigUnavailable.
  ///
  /// In en, this message translates to:
  /// **'AI configuration is unavailable.'**
  String get aiConfigUnavailable;

  /// No description provided for @aiNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'AI assistance is not enabled.'**
  String get aiNotEnabled;

  /// No description provided for @aiAccountProviderHint.
  ///
  /// In en, this message translates to:
  /// **'Meo Account invokes your saved connection; the API key is never sent to OmniStore.'**
  String get aiAccountProviderHint;

  /// No description provided for @aiSystemProviderHint.
  ///
  /// In en, this message translates to:
  /// **'Meo Account invokes the connection from KWallet; OmniStore sees only metadata and the final result.'**
  String get aiSystemProviderHint;

  /// No description provided for @aiOllamaProviderHint.
  ///
  /// In en, this message translates to:
  /// **'Ollama connects only to the local service and does not require an API key.'**
  String get aiOllamaProviderHint;

  /// No description provided for @aiCompatibleProviderHint.
  ///
  /// In en, this message translates to:
  /// **'Use only a trusted HTTPS-compatible endpoint; the key remains in the local secure store.'**
  String get aiCompatibleProviderHint;

  /// No description provided for @aiLocalKeyProviderHint.
  ///
  /// In en, this message translates to:
  /// **'This provider has a separate key in Secret Service/KWallet that cannot be read back.'**
  String get aiLocalKeyProviderHint;

  /// No description provided for @meoAccountOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open Meo Account.'**
  String get meoAccountOpenFailed;

  /// No description provided for @secureCredentialWriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to write to the system credential store.'**
  String get secureCredentialWriteFailed;

  /// No description provided for @modelsNoneFound.
  ///
  /// In en, this message translates to:
  /// **'The service is running, but no installed or available models were reported.'**
  String get modelsNoneFound;

  /// No description provided for @modelsAutofilled.
  ///
  /// In en, this message translates to:
  /// **'A discovered model was filled in automatically.'**
  String get modelsAutofilled;

  /// No description provided for @modelsFoundChoose.
  ///
  /// In en, this message translates to:
  /// **'Models were found. Choose one before testing; OmniStore does not infer capabilities from names.'**
  String get modelsFoundChoose;

  /// No description provided for @apiKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a new API key first.'**
  String get apiKeyRequired;

  /// No description provided for @secureCredentialSaved.
  ///
  /// In en, this message translates to:
  /// **'The API key was saved to the system credential store.'**
  String get secureCredentialSaved;

  /// No description provided for @localApiKeyDeleted.
  ///
  /// In en, this message translates to:
  /// **'The local API key was deleted.'**
  String get localApiKeyDeleted;

  /// No description provided for @secureCredentialUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to access the system credential store.'**
  String get secureCredentialUnavailable;

  /// No description provided for @signInMeoAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Meo Account'**
  String get signInMeoAccount;

  /// No description provided for @signInMeoAccountDetail.
  ///
  /// In en, this message translates to:
  /// **'After signing in, choose an encrypted account AI connection. Its API key is never sent to OmniStore.'**
  String get signInMeoAccountDetail;

  /// No description provided for @accountAiLoading.
  ///
  /// In en, this message translates to:
  /// **'Reading account AI connections'**
  String get accountAiLoading;

  /// No description provided for @accountAiMetadataOnly.
  ///
  /// In en, this message translates to:
  /// **'Only names, providers, and masked key status are read.'**
  String get accountAiMetadataOnly;

  /// No description provided for @accountAiLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to read account AI connections'**
  String get accountAiLoadError;

  /// No description provided for @accountAiNone.
  ///
  /// In en, this message translates to:
  /// **'No AI connection is saved in this account'**
  String get accountAiNone;

  /// No description provided for @accountAiNoneDetail.
  ///
  /// In en, this message translates to:
  /// **'Add your API key securely in Account, then return here and refresh.'**
  String get accountAiNoneDetail;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @accountAiSelectLabel.
  ///
  /// In en, this message translates to:
  /// **'Account AI connection'**
  String get accountAiSelectLabel;

  /// No description provided for @accountAiConnectionHelper.
  ///
  /// In en, this message translates to:
  /// **'The key is decrypted only inside the Account Edge broker; OmniStore cannot read it.'**
  String get accountAiConnectionHelper;

  /// No description provided for @manageAiConnections.
  ///
  /// In en, this message translates to:
  /// **'Manage AI connections'**
  String get manageAiConnections;

  /// No description provided for @aiPerRequestConsentDetail.
  ///
  /// In en, this message translates to:
  /// **'Before every request, OmniStore shows the provider, model, purpose, data categories, full content, and request fingerprint, then asks for one-time consent.'**
  String get aiPerRequestConsentDetail;

  /// No description provided for @aiEnabledConsentDesc.
  ///
  /// In en, this message translates to:
  /// **'Off by default; every request still requires separate confirmation after it is enabled.'**
  String get aiEnabledConsentDesc;

  /// No description provided for @providerLocalSecureKey.
  ///
  /// In en, this message translates to:
  /// **'{provider} (local secure key)'**
  String providerLocalSecureKey(String provider);

  /// No description provided for @providerCompatibleHttps.
  ///
  /// In en, this message translates to:
  /// **'OpenAI Compatible (custom HTTPS)'**
  String get providerCompatibleHttps;

  /// No description provided for @providerMeoAccount.
  ///
  /// In en, this message translates to:
  /// **'Meo Account'**
  String get providerMeoAccount;

  /// No description provided for @ollamaEndpointSafety.
  ///
  /// In en, this message translates to:
  /// **'Defaults to local Ollama. Keep a loopback address to avoid contacting a LAN service accidentally.'**
  String get ollamaEndpointSafety;

  /// No description provided for @compatibleEndpointSafety.
  ///
  /// In en, this message translates to:
  /// **'Enter only a trusted HTTPS-compatible endpoint without a key or query parameters.'**
  String get compatibleEndpointSafety;

  /// No description provided for @accountModelOverride.
  ///
  /// In en, this message translates to:
  /// **'Account model'**
  String get accountModelOverride;

  /// No description provided for @accountModelDefaultHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the selected Account connection\'s default model.'**
  String get accountModelDefaultHelper;

  /// No description provided for @modelReviewHelper.
  ///
  /// In en, this message translates to:
  /// **'The actual model is shown again for confirmation before every request.'**
  String get modelReviewHelper;

  /// No description provided for @detectLocalModels.
  ///
  /// In en, this message translates to:
  /// **'Detect local models and fill one in'**
  String get detectLocalModels;

  /// No description provided for @readModelCatalog.
  ///
  /// In en, this message translates to:
  /// **'Read model catalog'**
  String get readModelCatalog;

  /// No description provided for @installOllamaWithOmniStore.
  ///
  /// In en, this message translates to:
  /// **'Install Ollama with OmniStore'**
  String get installOllamaWithOmniStore;

  /// No description provided for @chooseDiscoveredModel.
  ///
  /// In en, this message translates to:
  /// **'Choose a discovered model'**
  String get chooseDiscoveredModel;

  /// No description provided for @localKeyStored.
  ///
  /// In en, this message translates to:
  /// **'A separate secure key is saved for this provider'**
  String get localKeyStored;

  /// No description provided for @localKeyNotStored.
  ///
  /// In en, this message translates to:
  /// **'No API key is saved for this provider'**
  String get localKeyNotStored;

  /// No description provided for @localKeysHelper.
  ///
  /// In en, this message translates to:
  /// **'Each provider is stored separately in Secret Service/KWallet; keys can be replaced or deleted but never read back.'**
  String get localKeysHelper;

  /// No description provided for @newApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'New API key (cleared after saving)'**
  String get newApiKeyLabel;

  /// No description provided for @newApiKeyHelper.
  ///
  /// In en, this message translates to:
  /// **'Enter only a replacement key. Existing keys cannot be read or copied.'**
  String get newApiKeyHelper;

  /// No description provided for @hideInput.
  ///
  /// In en, this message translates to:
  /// **'Hide input'**
  String get hideInput;

  /// No description provided for @showInput.
  ///
  /// In en, this message translates to:
  /// **'Show input'**
  String get showInput;

  /// No description provided for @saveOrReplace.
  ///
  /// In en, this message translates to:
  /// **'Save securely / Replace'**
  String get saveOrReplace;

  /// No description provided for @deleteLocalKey.
  ///
  /// In en, this message translates to:
  /// **'Delete local key'**
  String get deleteLocalKey;

  /// No description provided for @temperatureHelper.
  ///
  /// In en, this message translates to:
  /// **'0–2; lower values are usually more stable, and out-of-range values are not saved.'**
  String get temperatureHelper;

  /// No description provided for @aiTestScopeHelper.
  ///
  /// In en, this message translates to:
  /// **'Testing checks only the current connection and does not change the AI enable switch; real requests still require one-time consent.'**
  String get aiTestScopeHelper;

  /// No description provided for @meoUpdateChannel.
  ///
  /// In en, this message translates to:
  /// **'Meo update channel'**
  String get meoUpdateChannel;

  /// No description provided for @meoUpdateChannelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read from your active Pacman repositories'**
  String get meoUpdateChannelSubtitle;

  /// No description provided for @meoChannelChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking update channel…'**
  String get meoChannelChecking;

  /// No description provided for @meoChannelStable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get meoChannelStable;

  /// No description provided for @meoChannelBeta.
  ///
  /// In en, this message translates to:
  /// **'Beta'**
  String get meoChannelBeta;

  /// No description provided for @meoChannelBetaSummary.
  ///
  /// In en, this message translates to:
  /// **'Get newer Meo components before Stable. Arch system packages keep their normal repositories.'**
  String get meoChannelBetaSummary;

  /// No description provided for @meoChannelStableSummary.
  ///
  /// In en, this message translates to:
  /// **'Get fully tested MeoArch release trains.'**
  String get meoChannelStableSummary;

  /// No description provided for @meoChannelRepositoryPriority.
  ///
  /// In en, this message translates to:
  /// **'Repository priority: {repositories}'**
  String meoChannelRepositoryPriority(String repositories);

  /// No description provided for @meoChannelBetaNotice.
  ///
  /// In en, this message translates to:
  /// **'Choose Beta only when you want newer components before Stable. It is not recommended for critical systems; Stable remains available as the fallback.'**
  String get meoChannelBetaNotice;

  /// No description provided for @meoChannelDowngradePending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Stable is selected, but 1 Meo package downgrade still needs your review.} other{Stable is selected, but {count} Meo package downgrades still need your review.}}'**
  String meoChannelDowngradePending(int count);

  /// No description provided for @meoChannelReviewDowngrades.
  ///
  /// In en, this message translates to:
  /// **'Review downgrades'**
  String get meoChannelReviewDowngrades;

  /// No description provided for @meoChannelSwitchToStable.
  ///
  /// In en, this message translates to:
  /// **'Switch to Stable'**
  String get meoChannelSwitchToStable;

  /// No description provided for @meoChannelRollbackPreviewInvalid.
  ///
  /// In en, this message translates to:
  /// **'This Stable rollback preview is no longer valid. Refresh it and review it again.'**
  String get meoChannelRollbackPreviewInvalid;

  /// No description provided for @meoChannelDowngradeDialog.
  ///
  /// In en, this message translates to:
  /// **'These official Meo packages will move to their Stable versions. Arch and third-party packages won\'t be downgraded.\\n\\n{packages}'**
  String meoChannelDowngradeDialog(String packages);

  /// No description provided for @sourceFilterSemantics.
  ///
  /// In en, this message translates to:
  /// **'Filter by source: {name}'**
  String sourceFilterSemantics(String name);

  /// No description provided for @aiConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Review this AI request'**
  String get aiConsentTitle;

  /// No description provided for @aiConsentIntro.
  ///
  /// In en, this message translates to:
  /// **'Review the exact request before sending it. Your confirmation applies only to this request and its fingerprint.'**
  String get aiConsentIntro;

  /// No description provided for @aiConsentProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get aiConsentProvider;

  /// No description provided for @aiConsentDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get aiConsentDestination;

  /// No description provided for @aiConsentModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get aiConsentModel;

  /// No description provided for @aiConsentPurpose.
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get aiConsentPurpose;

  /// No description provided for @aiConsentDataCategories.
  ///
  /// In en, this message translates to:
  /// **'Data included'**
  String get aiConsentDataCategories;

  /// No description provided for @aiConsentCharacters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get aiConsentCharacters;

  /// No description provided for @aiConsentFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get aiConsentFingerprint;

  /// No description provided for @aiConsentReviewContent.
  ///
  /// In en, this message translates to:
  /// **'Review content to be sent'**
  String get aiConsentReviewContent;

  /// No description provided for @aiConsentSystemInstruction.
  ///
  /// In en, this message translates to:
  /// **'System instruction'**
  String get aiConsentSystemInstruction;

  /// No description provided for @aiConsentUserContent.
  ///
  /// In en, this message translates to:
  /// **'Your content'**
  String get aiConsentUserContent;

  /// No description provided for @aiConsentConfirmWithProvider.
  ///
  /// In en, this message translates to:
  /// **'I understand this content will be sent to {provider}.'**
  String aiConsentConfirmWithProvider(String provider);

  /// No description provided for @aiConsentKeyNotExposed.
  ///
  /// In en, this message translates to:
  /// **'Your API key is not part of this prompt and is not shown here.'**
  String get aiConsentKeyNotExposed;

  /// No description provided for @aiConsentDeny.
  ///
  /// In en, this message translates to:
  /// **'Don\'t send'**
  String get aiConsentDeny;

  /// No description provided for @aiConsentAllowOnce.
  ///
  /// In en, this message translates to:
  /// **'Confirm and send once'**
  String get aiConsentAllowOnce;

  /// No description provided for @aiConsentCategoryAppName.
  ///
  /// In en, this message translates to:
  /// **'App name'**
  String get aiConsentCategoryAppName;

  /// No description provided for @aiConsentCategoryAppDescription.
  ///
  /// In en, this message translates to:
  /// **'App description'**
  String get aiConsentCategoryAppDescription;

  /// No description provided for @aiConsentCategoryVersionMetadata.
  ///
  /// In en, this message translates to:
  /// **'Version information'**
  String get aiConsentCategoryVersionMetadata;

  /// No description provided for @aiConsentCategoryPackageSource.
  ///
  /// In en, this message translates to:
  /// **'Package source'**
  String get aiConsentCategoryPackageSource;

  /// No description provided for @aiConsentCategoryPackageVariants.
  ///
  /// In en, this message translates to:
  /// **'Installation options'**
  String get aiConsentCategoryPackageVariants;

  /// No description provided for @aiConsentCategoryPreferenceRequest.
  ///
  /// In en, this message translates to:
  /// **'Preference request'**
  String get aiConsentCategoryPreferenceRequest;

  /// No description provided for @aiConsentCategorySearchQuery.
  ///
  /// In en, this message translates to:
  /// **'Search query'**
  String get aiConsentCategorySearchQuery;

  /// No description provided for @aiConsentCategorySystemEnvironment.
  ///
  /// In en, this message translates to:
  /// **'System environment summary'**
  String get aiConsentCategorySystemEnvironment;

  /// No description provided for @aiConsentCategoryErrorLog.
  ///
  /// In en, this message translates to:
  /// **'Error log'**
  String get aiConsentCategoryErrorLog;

  /// No description provided for @aiConsentCategoryRecommendationRequest.
  ///
  /// In en, this message translates to:
  /// **'Recommendation request'**
  String get aiConsentCategoryRecommendationRequest;

  /// No description provided for @aiConsentCategoryConnectionTest.
  ///
  /// In en, this message translates to:
  /// **'Connection test data'**
  String get aiConsentCategoryConnectionTest;

  /// No description provided for @githubLoadErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'Could not load GitHub repositories. Check your network and try again.'**
  String get githubLoadErrorDetail;

  /// No description provided for @githubSearchErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'Could not search GitHub repositories. Check your network and try again.'**
  String get githubSearchErrorDetail;

  /// No description provided for @flatpakLoadErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'Could not load Flatpak apps. Check Flathub and your network connection, then try again.'**
  String get flatpakLoadErrorDetail;

  /// No description provided for @appCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'App: {name}'**
  String appCardSemantics(String name);

  /// No description provided for @diskSize.
  ///
  /// In en, this message translates to:
  /// **'Disk size'**
  String get diskSize;

  /// No description provided for @diskSizeWithConfidence.
  ///
  /// In en, this message translates to:
  /// **'Disk size ({confidence})'**
  String diskSizeWithConfidence(String confidence);

  /// No description provided for @accountAiSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Meo Account before using Account AI.'**
  String get accountAiSignInRequired;

  /// No description provided for @accountAiNoDefaultModel.
  ///
  /// In en, this message translates to:
  /// **'This AI connection has no default model. Choose a model in Settings first.'**
  String get accountAiNoDefaultModel;

  /// No description provided for @accountAiInvalidConsent.
  ///
  /// In en, this message translates to:
  /// **'The account AI service did not return a valid consent summary.'**
  String get accountAiInvalidConsent;

  /// No description provided for @accountAiConsentExpired.
  ///
  /// In en, this message translates to:
  /// **'The AI consent summary is invalid or expired.'**
  String get accountAiConsentExpired;

  /// No description provided for @accountAiInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The AI service did not return valid content.'**
  String get accountAiInvalidResponse;

  /// No description provided for @accountAiTestPurpose.
  ///
  /// In en, this message translates to:
  /// **'Test the OmniStore account AI connection'**
  String get accountAiTestPurpose;

  /// No description provided for @accountAiInvalidDestination.
  ///
  /// In en, this message translates to:
  /// **'The account AI connection has an invalid destination.'**
  String get accountAiInvalidDestination;

  /// No description provided for @accountAiConnectionNotFound.
  ///
  /// In en, this message translates to:
  /// **'The selected AI connection is unavailable. Choose it again in Settings.'**
  String get accountAiConnectionNotFound;

  /// No description provided for @accountAiInvalidData.
  ///
  /// In en, this message translates to:
  /// **'The account AI service returned invalid data.'**
  String get accountAiInvalidData;

  /// No description provided for @accountAiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The account AI service is temporarily unavailable.'**
  String get accountAiUnavailable;

  /// No description provided for @accountAiRequestDenied.
  ///
  /// In en, this message translates to:
  /// **'The account AI request was denied. Sign in again and try once more.'**
  String get accountAiRequestDenied;

  /// No description provided for @accountAiConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the account AI service.'**
  String get accountAiConnectionFailed;

  /// No description provided for @localAiUnsupportedModelDiscovery.
  ///
  /// In en, this message translates to:
  /// **'This connection does not support local model discovery.'**
  String get localAiUnsupportedModelDiscovery;

  /// No description provided for @localAiCredentialStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the secure credential store. Unlock KWallet and try again.'**
  String get localAiCredentialStoreUnavailable;

  /// No description provided for @localAiApiKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'Securely save an API key for this provider first.'**
  String get localAiApiKeyRequired;

  /// No description provided for @localAiCatalogTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The model catalog response is too large.'**
  String get localAiCatalogTooLarge;

  /// No description provided for @localAiInvalidCatalog.
  ///
  /// In en, this message translates to:
  /// **'The model catalog returned invalid data.'**
  String get localAiInvalidCatalog;

  /// No description provided for @localAiCatalogUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to read the model catalog. Check that the service is running.'**
  String get localAiCatalogUnavailable;

  /// No description provided for @localAiUnsupportedConnection.
  ///
  /// In en, this message translates to:
  /// **'This local AI connection type is not supported.'**
  String get localAiUnsupportedConnection;

  /// No description provided for @localAiInvalidModel.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid model name.'**
  String get localAiInvalidModel;

  /// No description provided for @localAiInvalidPurpose.
  ///
  /// In en, this message translates to:
  /// **'The AI request purpose is invalid.'**
  String get localAiInvalidPurpose;

  /// No description provided for @localAiInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'The AI input is empty or too large.'**
  String get localAiInvalidInput;

  /// No description provided for @localAiInvalidDataCategories.
  ///
  /// In en, this message translates to:
  /// **'The AI data categories are invalid.'**
  String get localAiInvalidDataCategories;

  /// No description provided for @localAiApiKeyInvalid.
  ///
  /// In en, this message translates to:
  /// **'The secure credential store has no valid API key for this provider.'**
  String get localAiApiKeyInvalid;

  /// No description provided for @localAiDestinationChanged.
  ///
  /// In en, this message translates to:
  /// **'The AI destination changed after consent, so the request was blocked.'**
  String get localAiDestinationChanged;

  /// No description provided for @localAiResponseTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The AI service response is too large.'**
  String get localAiResponseTooLarge;

  /// No description provided for @localAiInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The AI service returned invalid data.'**
  String get localAiInvalidResponse;

  /// No description provided for @localAiNoResponseText.
  ///
  /// In en, this message translates to:
  /// **'The AI service did not return text.'**
  String get localAiNoResponseText;

  /// No description provided for @localAiConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the AI service, or the request timed out.'**
  String get localAiConnectionFailed;

  /// No description provided for @localAiTestPurpose.
  ///
  /// In en, this message translates to:
  /// **'Test the OmniStore local secure AI connection'**
  String get localAiTestPurpose;

  /// No description provided for @localAiInvalidEndpoint.
  ///
  /// In en, this message translates to:
  /// **'The AI service address is invalid.'**
  String get localAiInvalidEndpoint;

  /// No description provided for @localAiOllamaLoopbackRequired.
  ///
  /// In en, this message translates to:
  /// **'The Ollama address must use local HTTP(S) loopback.'**
  String get localAiOllamaLoopbackRequired;

  /// No description provided for @localAiHttpsRequired.
  ///
  /// In en, this message translates to:
  /// **'Cloud AI services must use HTTPS.'**
  String get localAiHttpsRequired;

  /// No description provided for @localAiPrivateEndpointBlocked.
  ///
  /// In en, this message translates to:
  /// **'A compatible API cannot point to a local or private network. Use Ollama for local models.'**
  String get localAiPrivateEndpointBlocked;

  /// No description provided for @localAiOllama.
  ///
  /// In en, this message translates to:
  /// **'Ollama (on this device)'**
  String get localAiOllama;

  /// No description provided for @localAiApiKeyRejected.
  ///
  /// In en, this message translates to:
  /// **'The AI service rejected the API key.'**
  String get localAiApiKeyRejected;

  /// No description provided for @localAiModelOrEndpointNotFound.
  ///
  /// In en, this message translates to:
  /// **'The requested AI model or service address was not found.'**
  String get localAiModelOrEndpointNotFound;

  /// No description provided for @localAiRateLimited.
  ///
  /// In en, this message translates to:
  /// **'The AI service is out of quota or receiving requests too quickly.'**
  String get localAiRateLimited;

  /// No description provided for @localAiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The AI service is temporarily unavailable.'**
  String get localAiUnavailable;

  /// No description provided for @localAiRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'The AI service rejected the request (HTTP {status}).'**
  String localAiRequestRejected(int status);

  /// No description provided for @aiTestService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get aiTestService;

  /// No description provided for @aiTestConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get aiTestConnected;

  /// No description provided for @aiTestUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get aiTestUnavailable;

  /// No description provided for @aiTestReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get aiTestReady;

  /// No description provided for @aiTestNotReady.
  ///
  /// In en, this message translates to:
  /// **'Not ready'**
  String get aiTestNotReady;

  /// No description provided for @aiTestLatency.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get aiTestLatency;

  /// No description provided for @featuredAppSemantics.
  ///
  /// In en, this message translates to:
  /// **'Featured app: {name}'**
  String featuredAppSemantics(String name);
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
