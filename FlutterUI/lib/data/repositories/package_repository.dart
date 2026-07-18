import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_package.dart';
import '../../services/backend_service.dart';

class PackageRepository {
  Map<String, List<AppPackage>>? _cachedRecs;
  // ⚡ Bolt: Deduplicate simultaneous recommendation fetches and throttle automatic updates.
  Future<Map<String, List<AppPackage>>>? _activeFetchFuture;
  DateTime? _lastFetchTime;

  static final List<AppPackage> _editorialFeatured =
      [
            ['Firefox', 'org.mozilla.firefox', 'Fast, private web browsing.'],
            [
              'LibreOffice',
              'org.libreoffice.LibreOffice',
              'A complete, free office suite.',
            ],
            ['VLC', 'org.videolan.VLC', 'Play almost any media format.'],
            ['GIMP', 'org.gimp.GIMP', 'Powerful image editing for everyone.'],
            [
              'Visual Studio Code',
              'com.visualstudio.code',
              'Code editing, redefined.',
            ],
          ]
          .map(
            (entry) => AppPackage(
              name: entry[0],
              description: entry[2],
              id: entry[1],
              installed: false,
              primarySource: 'Flatpak',
              version: 'N/A',
              screenshots: const [],
              variants: [
                AppVariant(
                  source: 'Flatpak',
                  id: entry[1],
                  version: 'N/A',
                  installed: false,
                  description: entry[2],
                ),
              ],
            ),
          )
          .toList(growable: false);

  Map<String, List<AppPackage>> _withEditorialFeatured(
    Map<String, List<AppPackage>> dynamic,
  ) => {...dynamic, 'featured': _editorialFeatured};

  Future<List<AppPackage>> searchPackages(
    String query, {
    bool cancelOngoing = true,
    bool throwOnError = false,
    int? limit,
    int? offset,
  }) async {
    if (kIsWeb) {
      final webResults = await _webSearchPackages(query);
      return webResults
          .map((item) => AppPackage.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return BackendService.instance.searchPackages(
      query,
      cancelOngoing: cancelOngoing,
      throwOnError: throwOnError,
    );
  }

  Future<List<dynamic>> _webSearchPackages(String query) async {
    final results = <dynamic>[];
    if (query.length < 2) return results;

    final prefs = await SharedPreferences.getInstance();
    final configRaw = prefs.getString('omnistore_config');
    Map<String, dynamic> config = {};
    if (configRaw != null) {
      try {
        config = jsonDecode(configRaw);
      } catch (_) {}
    }

    final sourcesConfig = config['search']?['sources'] ?? {};
    final bool isGitHubEnabled = sourcesConfig['github'] ?? true;
    final bool isBituEnabled = sourcesConfig['bitu'] ?? true;

    final List<Future<List<dynamic>>> tasks = [];
    if (isGitHubEnabled) {
      tasks.add(_searchGitHub(query));
    }
    if (isBituEnabled) {
      tasks.add(_searchBitu(query));
    }

    if (tasks.isNotEmpty) {
      final responses = await Future.wait(tasks);
      for (final res in responses) {
        results.addAll(res);
      }
    }

    return results;
  }

  Future<List<dynamic>> _searchGitHub(String query) async {
    try {
      final response = await http
          .get(
            Uri.parse('https://api.github.com/search/repositories?q=$query'),
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'Omnistore/0.1',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      final items = data['items'] as List<dynamic>? ?? [];

      final prefs = await SharedPreferences.getInstance();
      final installedRaw = prefs.getStringList('omnistore_installed_ids') ?? [];

      return items.map((item) {
        final fullName = item['full_name'] as String;
        final isInstalled = installedRaw.contains(fullName);
        return {
          "name": item['name'] ?? '',
          "description": item['description'] ?? '',
          "installed": isInstalled,
          "primary_source": "GitHub",
          "url": item['html_url'] ?? '',
          "variants": [
            {"source": "GitHub", "id": fullName, "installed": isInstalled},
          ],
          "version": "Latest",
          "score": item['stargazers_count'] ?? 0,
          "icon": item['owner']?['avatar_url'] ?? '',
          "is_exact_match":
              (item['name'] as String).toLowerCase() == query.toLowerCase(),
          "screenshots": [],
        };
      }).toList();
    } catch (e) {
      debugPrint("GitHub Search Error: $e");
      return [];
    }
  }

  Future<List<dynamic>> _searchBitu(String query) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.bitbucket.org/2.0/repositories?q=name~"$query"',
            ),
            headers: {'User-Agent': 'Omnistore/0.1'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      final items = data['values'] as List<dynamic>? ?? [];

      final prefs = await SharedPreferences.getInstance();
      final installedRaw = prefs.getStringList('omnistore_installed_ids') ?? [];

      return items.map((item) {
        final fullName =
            item['full_name'] ??
            '${item['workspace']?['slug'] ?? 'workspace'}/${item['slug'] ?? 'repo'}';
        final isInstalled = installedRaw.contains(fullName);
        return {
          "name": item['name'] ?? '',
          "description": item['description'] ?? '',
          "installed": isInstalled,
          "primary_source": "Bitu",
          "url": item['links']?['html']?['href'] ?? '',
          "variants": [
            {"source": "Bitu", "id": fullName, "installed": isInstalled},
          ],
          "version": "Latest",
          "score": 0,
          "icon": item['links']?['avatar']?['href'] ?? '',
          "is_exact_match":
              (item['name'] as String).toLowerCase() == query.toLowerCase(),
          "screenshots": [],
        };
      }).toList();
    } catch (e) {
      debugPrint("Bitu Search Error: $e");
      return [];
    }
  }

  Future<List<AppPackage>> listInstalled({bool forceRefresh = false}) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('omnistore_installed_packages_cache');
        if (raw != null) {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            return decoded
                .whereType<Map<String, dynamic>>()
                .map((e) => AppPackage.fromJson(e))
                .toList();
          }
        }
        return [];
      } catch (_) {
        return [];
      }
    }
    return BackendService.instance.listInstalled(forceRefresh: forceRefresh);
  }

  Map<String, List<AppPackage>> _parseRecommendationsJson(dynamic data) {
    if (data is Map<String, dynamic>) {
      final Map<String, List<AppPackage>> categories = {};
      data.forEach((key, value) {
        if (value is List) {
          categories[key] = value
              .map((item) => AppPackage.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      });
      return categories;
    } else if (data is List) {
      return {
        "featured": data
            .map((item) => AppPackage.fromJson(item as Map<String, dynamic>))
            .toList(),
      };
    }
    return {};
  }

  Future<Map<String, List<AppPackage>>> getRecommendations({
    bool forceRefresh = false,
  }) async {
    if (_cachedRecs != null && !forceRefresh) {
      final now = DateTime.now();
      if (_activeFetchFuture == null &&
          (_lastFetchTime == null ||
              now.difference(_lastFetchTime!).inMinutes >= 5)) {
        _refreshRecommendationsCache();
      }
      return _cachedRecs!;
    }

    if (!forceRefresh) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString('omnistore_recommendations_cache');
        if (cachedJson != null) {
          final decoded = jsonDecode(cachedJson);
          final parsed = _parseRecommendationsJson(decoded);
          if (parsed.isNotEmpty) {
            _cachedRecs = _withEditorialFeatured(parsed);
            final now = DateTime.now();
            if (_activeFetchFuture == null &&
                (_lastFetchTime == null ||
                    now.difference(_lastFetchTime!).inMinutes >= 5)) {
              _refreshRecommendationsCache();
            }
            return _cachedRecs!;
          }
        }
      } catch (e) {
        debugPrint("Error reading recommendations cache: $e");
      }
    }

    if (forceRefresh) {
      return _fetchAndCacheRecommendations();
    }

    // The first frame never waits for a process or the network.
    _cachedRecs = _withEditorialFeatured({});
    _refreshRecommendationsCache();
    return _cachedRecs!;
  }

  Future<Map<String, List<AppPackage>>> _fetchAndCacheRecommendations() {
    if (_activeFetchFuture != null) {
      return _activeFetchFuture!;
    }
    _activeFetchFuture = _fetchAndCacheRecommendationsImpl();
    return _activeFetchFuture!;
  }

  Future<Map<String, List<AppPackage>>>
  _fetchAndCacheRecommendationsImpl() async {
    try {
      if (kIsWeb) {
        try {
          // Expand web recommendation sources beyond GitHub stars search (e.g. AUR, Flatpak web repositories).
          final githubUri = Uri.parse(
            'https://api.github.com/search/repositories?q=stars:>5000+OR+topic:flatpak+OR+topic:aur&sort=stars&order=desc',
          );
          final response = await http
              .get(githubUri, headers: {'User-Agent': 'Omnistore/0.1'})
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final items = data['items'] as List<dynamic>? ?? [];

            final prefs = await SharedPreferences.getInstance();
            final installedRaw =
                prefs.getStringList('omnistore_installed_ids') ?? [];

            final apps = items.map((item) {
              final fullName = item['full_name'] as String;
              final isInstalled = installedRaw.contains(fullName);
              return AppPackage(
                name: item['name'] ?? '',
                description: item['description'] ?? '',
                installed: isInstalled,
                primarySource: "GitHub",
                url: item['html_url'] ?? '',
                version: "Latest",
                icon: item['owner']?['avatar_url'],
                variants: [
                  AppVariant(
                    source: "GitHub",
                    version: "Latest",
                    installed: isInstalled,
                    id: fullName,
                    description: item['description'] ?? '',
                  ),
                ],
                screenshots: [],
              );
            }).toList();

            final results = {
              "featured": apps.take(5).toList(),
              "trending": apps.skip(5).take(5).toList(),
              "for_you": apps.skip(10).take(5).toList(),
            };
            _cachedRecs = _withEditorialFeatured(results);
            _lastFetchTime = DateTime.now();
            return _cachedRecs!;
          }
        } catch (e) {
          debugPrint("getRecommendations Web Exception: $e");
        }
        return _cachedRecs ?? _withEditorialFeatured({});
      } else {
        final results = await BackendService.instance.getRecommendations();
        if (results.isNotEmpty) {
          _cachedRecs = _withEditorialFeatured(results);
          _lastFetchTime = DateTime.now();
          try {
            final prefs = await SharedPreferences.getInstance();
            final Map<String, dynamic> jsonMap = {};
            results.forEach((key, list) {
              jsonMap[key] = list.map((app) => app.toJson()).toList();
            });
            await prefs.setString(
              'omnistore_recommendations_cache',
              jsonEncode(jsonMap),
            );
          } catch (e) {
            debugPrint("Error writing recommendations cache: $e");
          }
        }
        return _cachedRecs ?? _withEditorialFeatured(results);
      }
    } finally {
      _activeFetchFuture = null;
    }
  }

  void _refreshRecommendationsCache() {
    _fetchAndCacheRecommendations().catchError((e) {
      debugPrint("Background recommendations update failed: $e");
      return <String, List<AppPackage>>{};
    });
  }

  Future<AppPackage?> getAppDetails(String appId) async {
    if (kIsWeb) {
      try {
        if (appId.contains('/')) {
          final isGitHub =
              !appId.contains('bitbucket') && !appId.contains('bitu');
          final url = isGitHub
              ? 'https://api.github.com/repos/$appId'
              : 'https://api.bitbucket.org/2.0/repositories/$appId';

          final response = await http
              .get(Uri.parse(url), headers: {'User-Agent': 'Omnistore/0.1'})
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final repo = jsonDecode(response.body);
            final prefs = await SharedPreferences.getInstance();
            final installedRaw =
                prefs.getStringList('omnistore_installed_ids') ?? [];
            final isInstalled = installedRaw.contains(appId);

            return AppPackage.fromJson({
              "name": repo['name'] ?? '',
              "id": appId,
              "description": repo['description'] ?? '',
              "stars": repo['stargazers_count'] ?? 0,
              "forks": repo['forks_count'] ?? 0,
              "updated_at": repo['updated_at'] ?? repo['updated_on'] ?? '',
              "license": repo['license']?['name'] ?? '',
              "variants": [
                {
                  "source": isGitHub ? "GitHub" : "Bitu",
                  "id": appId,
                  "installed": isInstalled,
                },
              ],
            });
          }
        }
        return AppPackage.fromJson({
          "name": appId.split('/').last,
          "id": appId,
          "description":
              "Detailed package information is unavailable in web mode.",
          "variants": [],
        });
      } catch (e) {
        debugPrint("getAppDetails Web Exception: $e");
        return null;
      }
    }
    return BackendService.instance.getAppDetails(appId);
  }

  Future<List<dynamic>> getEssentials() async {
    if (kIsWeb) {
      return [
        {
          "name": "Visual Studio Code",
          "description": "Code editing. Redefined.",
          "installed": false,
          "primary_source": "GitHub",
          "url": "https://github.com/microsoft/vscode",
          "variants": [
            {"source": "GitHub", "id": "microsoft/vscode", "installed": false},
          ],
          "version": "Latest",
          "icon":
              "https://github.com/microsoft/vscode/raw/main/resources/win32/code.ico",
        },
        {
          "name": "Flutter SDK",
          "description":
              "Flutter makes it easy and fast to build beautiful apps for mobile and beyond.",
          "installed": false,
          "primary_source": "GitHub",
          "url": "https://github.com/flutter/flutter",
          "variants": [
            {"source": "GitHub", "id": "flutter/flutter", "installed": false},
          ],
          "version": "Latest",
          "icon":
              "https://github.com/flutter/flutter/raw/main/dev/integration_tests/flutter_gallery/assets/icons/gallery_ping.png",
        },
      ];
    }
    return BackendService.instance.getEssentials();
  }

  Future<bool> launchApp(String name, String source) async {
    if (kIsWeb) {
      final urlString = source.toLowerCase() == "github"
          ? "https://github.com/$name"
          : "https://bitbucket.org/$name";
      final uri = Uri.tryParse(urlString);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    }
    return BackendService.instance.launchApp(name, source);
  }

  Future<bool> locateApp(String name, String source) async {
    if (kIsWeb) {
      return launchApp(name, source);
    }
    return BackendService.instance.locateApp(name, source);
  }

  Future<List<dynamic>> importPackages(String filepath) async {
    if (kIsWeb) {
      return [];
    }
    return BackendService.instance.importPackages(filepath);
  }
}
