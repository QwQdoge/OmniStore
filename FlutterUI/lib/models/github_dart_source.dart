import 'dart:convert';
import 'package:http/http.dart' as http;
import 'source_base.dart';

class GitHubDartSource extends UnifiedSource {
  GitHubDartSource() : super(name: 'GitHub (Android)');

  final String _baseUrl = 'https://api.github.com';
  String? _pat;

  void updateToken(String? token) => _pat = token;

  Map<String, String> get _headers {
    final headers = {'Accept': 'application/vnd.github.v3+json'};
    if (_pat != null && _pat!.isNotEmpty) {
      headers['Authorization'] = 'token $_pat';
    }
    return headers;
  }

  @override
  Future<List<Map<String, dynamic>>> search(String query, {int page = 1, Map<String, dynamic>? filters}) async {
    final sort = filters?['sort'] ?? 'stars';
    final order = filters?['order'] ?? 'desc';

    final response = await http.get(
      Uri.parse('$_baseUrl/search/repositories?q=$query&sort=$sort&order=$order&page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data['items'] as List;
      return items.map((repo) => _mapRepo(repo)).toList();
    }
    return [];
  }

  Map<String, dynamic> _mapRepo(dynamic repo) {
    return {
      'name': repo['name'],
      'id': repo['full_name'],
      'description': repo['description'] ?? '',
      'source': 'GitHub',
      'icon': repo['owner']['avatar_url'],
      'url': repo['html_url'],
      'installed': false,
      'variants': [{'source': 'GitHub', 'id': repo['full_name']}]
    };
  }

  Future<List<Map<String, dynamic>>> getTrending() async {
    return await search('stars:>10000');
  }

  @override
  Future<bool> install(Map<String, dynamic> package, {Function(String)? onProgress}) async {
    // Android implementation:
    // 1. Fetch latest release
    // 2. Filter for APK
    // 3. Download and open with PackageInstaller intent
    return false;
  }

  @override
  Future<bool> uninstall(Map<String, dynamic> package, {Function(String)? onProgress}) async {
    return false;
  }

  @override
  Future<bool> launch(Map<String, dynamic> package) async {
    return false;
  }

  @override
  Future<bool> locate(Map<String, dynamic> package) async {
    return false;
  }

  @override
  Future<Map<String, dynamic>> getDetails(String packageId) async {
    final response = await http.get(Uri.parse('$_baseUrl/repos/$packageId'), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }

  @override
  Future<Map<String, dynamic>?> checkUpdate(String packageId) async {
    return null;
  }
}
