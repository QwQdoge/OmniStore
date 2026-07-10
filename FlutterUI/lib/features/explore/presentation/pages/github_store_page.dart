import 'package:frontend/features/explore/presentation/widgets/github_store_header.dart';
import "package:frontend/data/repositories/package_repository.dart";
import "package:provider/provider.dart";
import 'package:flutter/material.dart';
import 'package:frontend/models/app_package.dart';
import "package:frontend/features/explore/presentation/widgets/github_store_header.dart";
import 'package:frontend/features/explore/presentation/widgets/github_app_list.dart';
import 'package:frontend/features/explore/presentation/widgets/github_store_header.dart';

class GitHubStorePage extends StatefulWidget {
  const GitHubStorePage({super.key});

  @override
  State<GitHubStorePage> createState() => _GitHubStorePageState();
}

class _GitHubStorePageState extends State<GitHubStorePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Lists for each category
  List<AppPackage> _recommendedApps = [];
  List<AppPackage> _rankingApps = [];
  List<AppPackage> _trendingApps = [];
  List<AppPackage> _updatedApps = [];
  List<AppPackage> _searchApps = [];

  // Loading states
  bool _isLoadingRecommended = true;
  bool _isLoadingRankings = true;
  bool _isLoadingTrending = true;
  bool _isLoadingUpdated = true;
  bool _isLoadingSearch = false;

  String? _recommendedError;
  String? _rankingError;
  String? _trendingError;
  String? _updatedError;
  String? _searchError;

  bool _isSearching = false;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);

    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRecommended();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;

    // Lazy load tabs on switch
    switch (_tabController.index) {
      case 0:
        if (_recommendedApps.isEmpty) _fetchRecommended();
        break;
      case 1:
        if (_rankingApps.isEmpty) _fetchRankings();
        break;
      case 2:
        if (_trendingApps.isEmpty) _fetchTrending();
        break;
      case 3:
        if (_updatedApps.isEmpty) _fetchUpdated();
        break;
    }
  }

  Future<void> _fetchCategory({
    required String query,
    required void Function(bool) setLoading,
    required void Function(List<AppPackage>) setApps,
    required void Function(String?) setError,
  }) async {
    if (!mounted) return;
    setState(() {
      setLoading(true);
      setError(null);
    });
    final packageRepo = context.read<PackageRepository>();
    try {
      final results = await packageRepo.searchPackages(
        query,
        throwOnError: true,
      );
      if (!mounted) return;
      setState(() {
        setApps(results);
        setError(null);
        setLoading(false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        setError(
          "Could not load GitHub repositories. Check your network and try again.",
        );
        setLoading(false);
      });
    }
  }

  // Fetch Recommended (Default search:github)
  Future<void> _fetchRecommended() => _fetchCategory(
    query: "source:github",
    setLoading: (v) => _isLoadingRecommended = v,
    setApps: (v) => _recommendedApps = v,
    setError: (v) => _recommendedError = v,
  );

  // Fetch Rankings (stars:>5000 sort:stars)
  Future<void> _fetchRankings() => _fetchCategory(
    query: "source:github:stars:>5000 sort:stars",
    setLoading: (v) => _isLoadingRankings = v,
    setApps: (v) => _rankingApps = v,
    setError: (v) => _rankingError = v,
  );

  // Fetch Trending (stars:>1000 sort:forks)
  Future<void> _fetchTrending() => _fetchCategory(
    query: "source:github:stars:>1000 sort:forks",
    setLoading: (v) => _isLoadingTrending = v,
    setApps: (v) => _trendingApps = v,
    setError: (v) => _trendingError = v,
  );

  // Fetch Recently Updated (stars:>500 sort:updated)
  Future<void> _fetchUpdated() => _fetchCategory(
    query: "source:github:stars:>500 sort:updated",
    setLoading: (v) => _isLoadingUpdated = v,
    setApps: (v) => _updatedApps = v,
    setError: (v) => _updatedError = v,
  );

  // Handle Search
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchQuery = "";
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
      _isLoadingSearch = true;
      _searchError = null;
    });

    final packageRepo = context.read<PackageRepository>();
    try {
      // Direct query search in GitHub source
      final results = await packageRepo.searchPackages(
        "source:github:$query",
        throwOnError: true,
      );
      if (!mounted) return;
      setState(() {
        _searchApps = results;
        _searchError = null;
        _isLoadingSearch = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError =
            "Could not search GitHub repositories. Check your network and try again.";
        _isLoadingSearch = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchQuery = "";
      _searchApps = [];
      _searchError = null;
    });
  }

  Future<void> _handleRefresh() async {
    if (_isSearching) {
      await _performSearch(_searchQuery);
    } else {
      switch (_tabController.index) {
        case 0:
          await _fetchRecommended();
          break;
        case 1:
          await _fetchRankings();
          break;
        case 2:
          await _fetchTrending();
          break;
        case 3:
          await _fetchUpdated();
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Premium GitHub Store Hero Header
          GitHubStoreHeader(
            searchController: _searchController,
            isSearching: _isSearching,
            onSearchSubmitted: _performSearch,
            onClearSearch: _clearSearch,
          ),

          // Navigation / Tabs (Hidden when searching)
          GitHubStoreTabs(
            tabController: _tabController,
            isSearching: _isSearching,
          ),

          // Main Content Area
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.fastOutSlowIn,
                child: _isSearching
                    ? _buildSearchResultsView(
                        key: const ValueKey('search_results'),
                      )
                    : TabBarView(
                        key: const ValueKey('tab_bar_view'),
                        controller: _tabController,
                        children: [
                          _buildGitHubList(
                            apps: _recommendedApps,
                            isLoading: _isLoadingRecommended,
                            keyPrefix: 'recommended',
                            error: _recommendedError,
                          ),
                          _buildGitHubList(
                            apps: _rankingApps,
                            isLoading: _isLoadingRankings,
                            keyPrefix: 'rankings',
                            error: _rankingError,
                          ),
                          _buildGitHubList(
                            apps: _trendingApps,
                            isLoading: _isLoadingTrending,
                            keyPrefix: 'trending',
                            error: _trendingError,
                          ),
                          _buildGitHubList(
                            apps: _updatedApps,
                            isLoading: _isLoadingUpdated,
                            keyPrefix: 'updated',
                            error: _updatedError,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsView({Key? key}) {
    final hasError = _searchError != null;
    return GitHubAppList(
      key: key,
      apps: _searchApps,
      isLoading: _isLoadingSearch,
      keyPrefix: 'search',
      onRetry: _handleRefresh,
      emptyIcon: hasError ? Icons.cloud_off_rounded : Icons.search_off_rounded,
      emptyText: hasError ? "GitHub search failed" : "No results found",
      emptySubtitle: _searchError ?? "Try searching for something else",
      showRetry: hasError,
    );
  }

  Widget _buildGitHubList({
    required List<AppPackage> apps,
    required bool isLoading,
    required String keyPrefix,
    required String? error,
  }) {
    final hasError = error != null;
    return GitHubAppList(
      apps: apps,
      isLoading: isLoading,
      keyPrefix: keyPrefix,
      onRetry: _handleRefresh,
      emptyIcon: hasError ? Icons.cloud_off_rounded : Icons.inventory_2_rounded,
      emptyText: hasError
          ? "GitHub Store unavailable"
          : "No GitHub repositories found",
      emptySubtitle: error ?? "Pull to refresh or try another category.",
      showRetry: true,
    );
  }
}

