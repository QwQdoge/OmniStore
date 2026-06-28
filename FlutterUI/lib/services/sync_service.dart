import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_apps_tracker.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  Timer? _syncTimer;
  bool _isSyncing = false;

  /// Starts background sync process if user is logged in
  void startBackgroundSync() {
    // Check every hour or after specific triggers.
    // For now, we can just trigger it manually or use a periodic timer.
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      syncInstalledApps();
    });
  }

  void stopBackgroundSync() {
    _syncTimer?.cancel();
  }

  /// Manually trigger a sync
  Future<void> syncInstalledApps() async {
    if (_isSyncing) return;

    final SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      debugPrint('Sync aborted: Supabase is not initialized.');
      return;
    }

    final user = client.auth.currentUser;
    if (user == null) {
      debugPrint('Sync aborted: User not logged in.');
      return;
    }

    _isSyncing = true;
    try {
      final localApps = await LocalAppsTracker.getTrackedApps();

      // Update the user's installed apps in Supabase.
      // Assuming 'installed_apps' table with columns: id, user_id, app_id, installed_at

      // 1. Fetch current remote apps
      final remoteData = await client
          .from('installed_apps')
          .select('app_id')
          .eq('user_id', user.id);

      final Set<String> remoteApps = (remoteData as List)
          .map((row) => row['app_id'].toString())
          .toSet();
      final Set<String> localAppsSet = localApps.toSet();

      final appsToUpload = localAppsSet.difference(remoteApps);
      final appsToDelete = remoteApps.difference(localAppsSet);

      if (appsToUpload.isNotEmpty) {
        final insertPayload = appsToUpload
            .map(
              (appId) => {
                'user_id': user.id,
                'app_id': appId,
                'installed_at': DateTime.now().toIso8601String(),
              },
            )
            .toList();

        await client.from('installed_apps').insert(insertPayload);
      }

      if (appsToDelete.isNotEmpty) {
        await client
            .from('installed_apps')
            .delete()
            .eq('user_id', user.id)
            .inFilter('app_id', appsToDelete.toList());
      }

      debugPrint(
        'Sync successful: Uploaded ${appsToUpload.length}, Deleted ${appsToDelete.length}',
      );
    } catch (e) {
      debugPrint('Error syncing installed apps: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Fetches apps from the cloud (useful for restoring on a new device)
  Future<List<String>> fetchBackedUpApps() async {
    final SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      return [];
    }

    final user = client.auth.currentUser;
    if (user == null) {
      return [];
    }

    try {
      final data = await client
          .from('installed_apps')
          .select('app_id')
          .eq('user_id', user.id);

      return (data as List).map((row) => row['app_id'].toString()).toList();
    } catch (e) {
      debugPrint('Error fetching backed up apps: $e');
      return [];
    }
  }
}
