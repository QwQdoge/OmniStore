import sys

filepath = 'FlutterUI/lib/data/repositories/package_repository.dart'
with open(filepath, 'r') as f:
    content = f.read()

search_str = """  Future<List<AppPackage>> searchPackages(
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
  }"""

replace_str = """  final Map<String, Map<String, dynamic>> _searchCache = {};

  Future<List<AppPackage>> searchPackages(
    String query, {
    bool cancelOngoing = true,
    bool throwOnError = false,
    bool forceRefresh = false,
    int? limit,
    int? offset,
  }) async {
    final bool isSourceSearch = query.trim().startsWith('source:');

    if (isSourceSearch && !forceRefresh) {
      final cached = _searchCache[query];
      if (cached != null) {
        final time = cached['time'] as DateTime;
        if (DateTime.now().difference(time).inMinutes < 5) {
          return List<AppPackage>.from(cached['results'] as List);
        }
      }
    }

    List<AppPackage> results;
    if (kIsWeb) {
      final webResults = await _webSearchPackages(query);
      results = webResults
          .map((item) => AppPackage.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      results = await BackendService.instance.searchPackages(
        query,
        cancelOngoing: cancelOngoing,
        throwOnError: throwOnError,
      );
    }

    if (isSourceSearch) {
      _searchCache[query] = {
        'results': results,
        'time': DateTime.now(),
      };
    }

    return results;
  }"""

if search_str in content:
    content = content.replace(search_str, replace_str)
    with open(filepath, 'w') as f:
        f.write(content)
    print("Success")
else:
    print("Not found")
