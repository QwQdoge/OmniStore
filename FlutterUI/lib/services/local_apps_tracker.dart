import 'package:shared_preferences/shared_preferences.dart';

class LocalAppsTracker {
  static const String _key = 'omnistore_tracked_apps_v2';

  static Future<List<String>> getTrackedApps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<void> trackApp(String appId) async {
    final prefs = await SharedPreferences.getInstance();
    final apps = prefs.getStringList(_key) ?? [];
    if (!apps.contains(appId)) {
      apps.add(appId);
      await prefs.setStringList(_key, apps);
    }
  }

  static Future<void> untrackApp(String appId) async {
    final prefs = await SharedPreferences.getInstance();
    final apps = prefs.getStringList(_key) ?? [];
    if (apps.contains(appId)) {
      apps.remove(appId);
      await prefs.setStringList(_key, apps);
    }
  }

  static Future<bool> isTracked(String appId) async {
    final apps = await getTrackedApps();
    return apps.contains(appId);
  }
}
