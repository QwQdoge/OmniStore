import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class GitHubClient {
  static const String _baseUrl = 'https://api.github.com';
  static const String _cachePrefix = 'github_cache_';

  final String? token;
  final SharedPreferences prefs;

  GitHubClient({this.token, required this.prefs});

  Map<String, String> get _headers {
    final headers = {
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'OmniStore-App',
    };
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'token $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>?> getRepoDetails(String owner, String repo) async {
    final cacheKey = '${_cachePrefix}repo_${owner}_$repo';

    // Check cache first
    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      final decoded = jsonDecode(cachedData);
      final timestamp = decoded['timestamp'] as int;
      // Cache valid for 1 hour
      if (DateTime.now().millisecondsSinceEpoch - timestamp < 3600000) {
        return decoded['data'];
      }
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/repos/$owner/$repo'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Save to cache
        await prefs.setString(cacheKey, jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': data,
        }));
        return data;
      } else if (response.statusCode == 403) {
        debugPrint('GitHub API Rate Limit Exceeded');
      }
    } catch (e) {
      debugPrint('GitHub Client Error: $e');
    }

    // Fallback to expired cache if network fails
    if (cachedData != null) {
      return jsonDecode(cachedData)['data'];
    }
    return null;
  }

  Future<int> getStarCount(String owner, String repo) async {
    final details = await getRepoDetails(owner, repo);
    return details?['stargazers_count'] ?? 0;
  }

  /// Extracts owner and repo name from various GitHub URL formats
  static Map<String, String>? parseUrl(String url) {
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
}
