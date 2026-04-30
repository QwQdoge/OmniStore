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
}
