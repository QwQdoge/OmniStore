import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// GitHub REST client with prefs cache + in-memory LRU to reduce rate limits.
class GitHubClient {
  static const String _baseUrl = 'https://api.github.com';
  static const String _cachePrefix = 'github_cache_';
  static const Duration _cacheTtl = Duration(hours: 1);
  static const int _memoryCacheMax = 64;

  final String? token;
  final SharedPreferences prefs;

  final Map<String, _MemoryEntry> _memory = {};

  GitHubClient({this.token, required this.prefs});

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'OmniStore-App',
    };
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'token $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>?> getRepoDetails(
    String owner,
    String repo,
  ) async {
    final cacheKey = '${_cachePrefix}repo_${owner}_$repo';

    final mem = _memory[cacheKey];
    if (mem != null && !mem.isExpired) {
      return mem.data;
    }

    String? cachedData;
    try {
      cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final decoded = jsonDecode(cachedData) as Map<String, dynamic>;
        final timestamp = decoded['timestamp'] as int? ?? 0;
        if (DateTime.now().millisecondsSinceEpoch - timestamp <
            _cacheTtl.inMilliseconds) {
          final data = decoded['data'] as Map<String, dynamic>?;
          if (data != null) {
            _putMemory(cacheKey, data);
            return data;
          }
        }
      }
    } catch (e) {
      debugPrint('GitHub cache read error: $e');
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/repos/$owner/$repo'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = response.body;
        final data = await compute(_parseRepoJson, body);
        if (data != null) {
          await _persist(cacheKey, data);
          _putMemory(cacheKey, data);
          return data;
        }
      } else if (response.statusCode == 403) {
        debugPrint('GitHub API rate limit exceeded');
      }
    } catch (e) {
      debugPrint('GitHub client network error: $e');
    }

    if (cachedData != null) {
      try {
        final decoded = jsonDecode(cachedData) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;
        if (data != null) {
          _putMemory(cacheKey, data);
          return data;
        }
      } catch (_) {}
    }

    final stale = _memory[cacheKey];
    return stale?.data;
  }

  /// Synchronously check if star count is in memory or disk cache.
  int? getCachedStarCount(String owner, String repo) {
    final cacheKey = '${_cachePrefix}repo_${owner}_$repo';

    final mem = _memory[cacheKey];
    if (mem != null && !mem.isExpired) {
      return _extractStarCount(mem.data);
    }

    try {
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final decoded = jsonDecode(cachedData) as Map<String, dynamic>;
        final timestamp = decoded['timestamp'] as int? ?? 0;
        if (DateTime.now().millisecondsSinceEpoch - timestamp <
            _cacheTtl.inMilliseconds) {
          final data = decoded['data'] as Map<String, dynamic>?;
          if (data != null) {
            _putMemory(cacheKey, data);
            return _extractStarCount(data);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  int? getCachedStarCountFromUrl(String? url) {
    final parsed = parseUrl(url);
    if (parsed == null) return null;
    return getCachedStarCount(parsed['owner']!, parsed['repo']!);
  }

  Future<int?> getStarCount(String owner, String repo) async {
    final details = await getRepoDetails(owner, repo);
    return _extractStarCount(details);
  }

  Future<int?> getStarCountFromUrl(String? url) async {
    final parsed = parseUrl(url);
    if (parsed == null) return null;
    return getStarCount(parsed['owner']!, parsed['repo']!);
  }

  static int? _extractStarCount(Map<String, dynamic>? data) {
    if (data == null) return null;
    final count = data['stargazers_count'];
    if (count is int) return count;
    if (count is num) return count.toInt();
    return null;
  }

  static Map<String, String>? parseUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      if (!uri.host.contains('github.com')) return null;

      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length >= 2) {
        return {
          'owner': segments[0],
          'repo': segments[1].replaceAll('.git', ''),
        };
      }
    } catch (_) {}
    return null;
  }

  Future<void> _persist(String cacheKey, Map<String, dynamic> data) async {
    try {
      await prefs.setString(
        cacheKey,
        jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': data,
        }),
      );
    } catch (e) {
      debugPrint('GitHub cache write error: $e');
    }
  }

  void _putMemory(String key, Map<String, dynamic> data) {
    if (_memory.length >= _memoryCacheMax) {
      final oldest = _memory.entries.reduce(
        (a, b) => a.value.storedAt.isBefore(b.value.storedAt) ? a : b,
      );
      _memory.remove(oldest.key);
    }
    _memory[key] = _MemoryEntry(data, DateTime.now());
  }
}

class _MemoryEntry {
  _MemoryEntry(this.data, this.storedAt);

  final Map<String, dynamic> data;
  final DateTime storedAt;

  bool get isExpired =>
      DateTime.now().difference(storedAt) > GitHubClient._cacheTtl;
}

Map<String, dynamic>? _parseRepoJson(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return null;
}
