import "package:frontend/data/repositories/package_repository.dart";
import "package:provider/provider.dart";
import "package:frontend/features/explore/presentation/pages/details_page.dart";
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/core/network/github_client.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/core/widgets/app_source_tag.dart';
import 'package:frontend/core/widgets/github_star_badge.dart';
import 'package:frontend/core/widgets/skeleton.dart';

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

  // Fetch Recommended (Default search:github)
  Future<void> _fetchRecommended() async {
    if (!mounted) return;
    setState(() => _isLoadingRecommended = true);
    final packageRepo = context.read<PackageRepository>();
    try {
      final results = await packageRepo.searchPackages("source:github");
      if (mounted) {
        setState(() {
          _recommendedApps = results;
          _isLoadingRecommended = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRecommended = false);
    }
  }

  // Fetch Rankings (stars:>5000 sort:stars)
  Future<void> _fetchRankings() async {
    if (!mounted) return;
    setState(() => _isLoadingRankings = true);
    final packageRepo = context.read<PackageRepository>();
    try {
      final results = await packageRepo.searchPackages(
        "source:github:stars:>5000 sort:stars",
      );
      if (mounted) {
        setState(() {
          _rankingApps = results;
          _isLoadingRankings = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRankings = false);
    }
  }

  // Fetch Trending (stars:>1000 sort:forks)
  Future<void> _fetchTrending() async {
    if (!mounted) return;
    setState(() => _isLoadingTrending = true);
    final packageRepo = context.read<PackageRepository>();
    try {
      final results = await packageRepo.searchPackages(
        "source:github:stars:>1000 sort:forks",
      );
      if (mounted) {
        setState(() {
          _trendingApps = results;
          _isLoadingTrending = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTrending = false);
    }
  }

  // Fetch Recently Updated (stars:>500 sort:updated)
  Future<void> _fetchUpdated() async {
    if (!mounted) return;
    setState(() => _isLoadingUpdated = true);
    final packageRepo = context.read<PackageRepository>();
    try {
      final results = await packageRepo.searchPackages(
        "source:github:stars:>500 sort:updated",
      );
      if (mounted) {
        setState(() {
          _updatedApps = results;
          _isLoadingUpdated = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUpdated = false);
    }
  }

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
    });

    final packageRepo = context.read<PackageRepository>();
    try {
      // Direct query search in GitHub source
      final results = await packageRepo.searchPackages("source:github:$query");
      if (mounted) {
        setState(() {
          _searchApps = results;
          _isLoadingSearch = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSearch = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchQuery = "";
      _searchApps = [];
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Premium GitHub Store Hero Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        scheme.surfaceContainerHigh,
                        scheme.surfaceContainerLowest,
                      ]
                    : [
                        scheme.surfaceContainerLowest,
                        scheme.surfaceContainerLow,
                      ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Glassmorphic GitHub Icon Container
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.3 : 0.05,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Image.network(
                        "https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png",
                        width: 32,
                        height: 32,
                        color: isDark ? Colors.white : Colors.black87,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.code_rounded, size: 32),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "GitHub App Store",
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "Discover and download apps directly from GitHub releases",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Premium Integrated Search Bar
                SearchBar(
                  controller: _searchController,
                  hintText: "Search GitHub repositories...",
                  leading: const Icon(Icons.search_rounded),
                  trailing: [
                    if (_isSearching)
                      IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.clear_rounded),
                      ),
                  ],
                  elevation: WidgetStateProperty.all(0),
                  backgroundColor: WidgetStateProperty.all(
                    scheme.surfaceContainerHigh.withValues(alpha: 0.7),
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  onSubmitted: _performSearch,
                ),
              ],
            ),
          ),

          // Navigation / Tabs (Hidden when searching)
          if (!_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                  ),
                  labelColor: scheme.onPrimaryContainer,
                  unselectedLabelColor: scheme.onSurfaceVariant,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(
                      text: "推荐",
                      icon: Icon(Icons.recommend_rounded, size: 20),
                    ),
                    Tab(
                      text: "排行榜",
                      icon: Icon(Icons.leaderboard_rounded, size: 20),
                    ),
                    Tab(
                      text: "热度榜",
                      icon: Icon(Icons.local_fire_department_rounded, size: 20),
                    ),
                    Tab(
                      text: "最新更新",
                      icon: Icon(Icons.update_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),

          // Main Content Area
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: _isSearching
                  ? _buildSearchResultsView()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAppListView(
                          _recommendedApps,
                          _isLoadingRecommended,
                          'recommended',
                        ),
                        _buildAppListView(
                          _rankingApps,
                          _isLoadingRankings,
                          'rankings',
                        ),
                        _buildAppListView(
                          _trendingApps,
                          _isLoadingTrending,
                          'trending',
                        ),
                        _buildAppListView(
                          _updatedApps,
                          _isLoadingUpdated,
                          'updated',
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsView() {
    if (_isLoadingSearch) {
      return _buildSkeletonList();
    }
    if (_searchApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              "No results found",
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Try searching for something else",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return _buildAppListView(_searchApps, false, 'search');
  }

  Widget _buildAppListView(
    List<AppPackage> apps,
    bool isLoading,
    String keyPrefix,
  ) {
    if (isLoading) {
      return _buildSkeletonList();
    }

    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              "No packages available",
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _handleRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    final client = context.read<GitHubClient>();
    final scheme = Theme.of(context).colorScheme;

    return ListView.builder(
      key: PageStorageKey<String>('github_store_$keyPrefix'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final repoUrl = app.url ?? app.homepage;

        return Card.filled(
          margin: const EdgeInsets.only(bottom: 12),
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AppDetailsPage(app: app)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Icon
                  Hero(
                    tag: 'app_icon_${app.id}_$keyPrefix',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: scheme.surfaceContainerHighest,
                        width: 56,
                        height: 56,
                        child: app.icon != null
                            ? CachedNetworkImage(
                                imageUrl: app.icon!,
                                width: 56,
                                height: 56,
                                memCacheWidth: 112,
                                memCacheHeight: 112,
                                fit: BoxFit.cover,
                                errorWidget: (c, e, s) =>
                                    const Icon(Icons.code_rounded, size: 28),
                              )
                            : const Icon(Icons.code_rounded, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // App Info Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                app.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Stars Badge
                            if (GitHubClient.parseUrl(repoUrl) != null)
                              GitHubStarBadge(
                                client: client,
                                repositoryUrl: repoUrl,
                                compact: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          app.description.isNotEmpty
                              ? app.description
                              : "No description provided.",
                          style: TextStyle(
                            fontSize: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Show source
                            AppSourceTag(
                              source: app.primarySource,
                              mode: AppSourceTagMode.source,
                            ),
                            const Spacer(),
                            // Detail link indication
                            Text(
                              "View Details",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: scheme.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonList({Key? key}) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      key: key,
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Card.filled(
          margin: const EdgeInsets.only(bottom: 12),
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 56, height: 56, borderRadius: 16),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Skeleton(width: 140, height: 18),
                          Skeleton(width: 60, height: 20, borderRadius: 6),
                        ],
                      ),
                      SizedBox(height: 8),
                      Skeleton(width: double.infinity, height: 14),
                      SizedBox(height: 6),
                      Skeleton(width: 200, height: 14),
                      SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Skeleton(width: 80, height: 22, borderRadius: 6),
                          Skeleton(width: 70, height: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
