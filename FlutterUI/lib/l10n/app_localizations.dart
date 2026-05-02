import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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
    Locale('zh'),
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

  /// Label for the installation button
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
  /// **'OmniStore: Found {count} updates'**
  String trayTooltipUpdates(Object count);

  /// No description provided for @trayTooltipUpToDate.
  ///
  /// In en, this message translates to:
  /// **'OmniStore: Up to date'**
  String get trayTooltipUpToDate;

  /// Description for updateReminders
  ///
  /// In en, this message translates to:
  /// **'Update Reminders'**
  String get updateReminders;

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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
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
