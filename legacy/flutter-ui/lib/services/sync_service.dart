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
    _syncTimer = null;
  }

  /// Manually trigger a sync
  static const _snapshotSource = 'omnistore';
  static const _snapshotFormat =
      'application/vnd.meo.omnistore.library+json;version=1';

  Future<bool> syncInstalledApps() async {
    if (_isSyncing) return false;

    final SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      debugPrint('Sync aborted: Supabase is not initialized.');
      return false;
    }

    final user = client.auth.currentUser;
    if (user == null) {
      debugPrint('Sync aborted: User not logged in.');
      return false;
    }

    _isSyncing = true;
    try {
      final localApps = await LocalAppsTracker.getTrackedApps();
      final normalizedApps = localApps.toSet().toList()..sort();

      // Keep one compact, versioned document per user. The database enforces a
      // 1 MiB limit and RLS restricts every row to auth.uid(). No local config,
      // API key, access token, or machine identifier is uploaded.
      await client.from('user_library_snapshots').upsert({
        'user_id': user.id,
        'source': _snapshotSource,
        'export_format': _snapshotFormat,
        'content': {'schema_version': 1, 'apps': normalizedApps},
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,source');

      debugPrint('Sync successful: ${normalizedApps.length} app IDs saved.');
      return true;
    } catch (e) {
      debugPrint('Error syncing installed apps: $e');
      return false;
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
      final snapshot = await client
          .from('user_library_snapshots')
          .select('content')
          .eq('user_id', user.id)
          .eq('source', _snapshotSource)
          .maybeSingle();
      final content = snapshot?['content'];
      final apps = content is Map ? content['apps'] : null;
      if (apps is List) {
        return apps.whereType<String>().toSet().toList()..sort();
      }

      // Compatibility with the older row-per-app representation.
      final legacyRows = await client
          .from('installed_apps')
          .select('app_id')
          .eq('user_id', user.id);
      return (legacyRows as List)
          .map((row) => row['app_id'].toString())
          .toSet()
          .toList()
        ..sort();
    } catch (e) {
      debugPrint('Error fetching backed up apps: $e');
      return [];
    }
  }
}
