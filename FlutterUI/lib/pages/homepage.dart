import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import '../l10n/app_localizations.dart';
import '../services/app_package.dart';
import '../services/backend_service.dart';
import '../services/category_service.dart';

import '../widgets/ai_app_resolver.dart';
import './app_details_page.dart';
import 'searchpage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, List<AppPackage>> _recommendationMap = {};
  List<dynamic> _essentials = [];
  bool _isLoading = true;
  String? _aiPickBlurb;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final recFuture = BackendService.instance.getRecommendations();
    final essFuture = BackendService.instance.getEssentials();

    final results = await Future.wait([recFuture, essFuture]);

    if (mounted) {
      setState(() {
        _recommendationMap = results[0] as Map<String, List<AppPackage>>;
        _essentials = results[1] as List<dynamic>;
        _isLoading = false;
      });
      _fetchAIPick();
    }
  }

  bool _isAILoading = false;
  Future<void> _fetchAIPick() async {
    if (!BackendService.isAIEnabled.value) return;
    setState(() => _isAILoading = true);
    try {
      final pick = await BackendService.instance.aiPickOfTheDay();
      if (mounted) {
        setState(() {
          _aiPickBlurb = pick;
          _isAILoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isAILoading = false);
    }
  }

  Future<void> _importPackages() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'json'],
    );

    if (result != null) {
      final path = result.files.single.path!;
      final packages = await BackendService.instance.importPackages(path);
      if (mounted && packages.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("导入软件包"),
            content: Text("已从文件中读取 ${packages.length} 个软件包。是否开始批量下载？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  for (var pkg in packages) {
                    final name = pkg['name'] as String;
                    final source = pkg['source'] as String? ?? 'Native';
                    _executeInstall(name, source);
                  }
                },
                child: const Text("全部下载"),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final featured = _recommendationMap['featured'] ?? [];
    final trending = _recommendationMap['trending'] ?? [];
    final forYou = _recommendationMap['for_you'] ?? [];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            // 1. Hero Section (Featured)
            SliverToBoxAdapter(
              child: _buildHeroSection(featured),
            ),

            // AI Pick of the Day
            ValueListenableBuilder<bool>(
              valueListenable: BackendService.isAIEnabled,
              builder: (context, enabled, _) {
                if (!enabled) return const SliverToBoxAdapter(child: SizedBox.shrink());
                if (_isAILoading) {
                  return SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      height: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  );
                }
                if (_aiPickBlurb != null && _aiPickBlurb!.isNotEmpty) {
                  return SliverToBoxAdapter(child: _buildAIPickSection());
                }
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              },
            ),

            // 1.5 Categories Quick Access
            _buildCategoryQuickAccess(),

            // 2. Essentials Grid
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 40, bottom: 16),
                child: Row(
                  children: [
                    Expanded(child: _buildSectionHeader(l10n.essentialTools)),
                    Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: OutlinedButton.icon(
                        onPressed: _importPackages,
                        icon: const Icon(Icons.file_upload_rounded, size: 18),
                        label: const Text("导入列表"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    mainAxisExtent: 80,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildEssentialCard(_essentials[index]),
                    childCount: _essentials.length,
                  ),
                ),
              ),

            // 3. Trending Shelf
            SliverToBoxAdapter(
              child: _buildCategoryShelf(l10n.hotApps, trending),
            ),

            // 4. Personalization Shelf (For You)
            if (forYou.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildCategoryShelf(l10n.forYou, forYou),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(List<AppPackage> apps) {
    if (_isLoading) {
      return Container(
        height: 280,
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(28.0),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (apps.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, color: Theme.of(context).colorScheme.error, size: 48),
              const SizedBox(height: 12),
              const Text("无法加载推荐内容，请检查后端状态"),
              FilledButton.tonal(onPressed: _refresh, child: const Text("重试")),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionHeader(AppLocalizations.of(context)!.featured),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: apps.length,
            separatorBuilder: (context, index) => const SizedBox(width: 20),
            itemBuilder: (context, index) => _buildBannerCard(context, apps[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryShelf(String title, List<AppPackage> apps) {
    if (apps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 48),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SearchPage(autoFocus: true),
                    ),
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.apps_rounded, size: 16),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context)!.about), // Fallback for 'View More'
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: apps.length,
            itemBuilder: (context, index) =>
                _buildShelfItem(context, apps[index]),
          ),
        ),
      ],
    );
  }

  // (Section 6: HomePage Shelves)
  Widget _buildShelfItem(BuildContext context, AppPackage app) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AppDetailsPage(app: app)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Hero(
                  tag: 'app-icon-shelf-${app.name}-${app.primarySource}',
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                    child: app.icon != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14.0),
                            child: CachedNetworkImage(
                              imageUrl: app.icon!,
                              fit: BoxFit.cover,
                              errorWidget: (c, e, s) => Center(
                                child: Text(
                                  app.name[0].toUpperCase(),
                                  style: TextStyle(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              app.name[0].toUpperCase(),
                              style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.description,
                        style: TextStyle(
                            fontSize: 12, color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _buildTrustLabel(app.primarySource),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // (Section 5: Category Chips)
  Widget _buildCategoryQuickAccess() {
    final categories = CategoryService.getCategories(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          _buildSectionHeader(AppLocalizations.of(context)!.category),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final cat = categories[index];
                return ActionChip(
                  onPressed: () {
                    BackendService.navigationIndex.value = 2; // Search tab
                    BackendService.pendingSearchQuery.value = '/${cat.id.toLowerCase()}';
                  },
                  avatar: Icon(cat.icon, size: 18, color: colorScheme.primary),
                  label: Text(cat.name),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide.none,
                  backgroundColor: colorScheme.surfaceContainerHigh,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.0,
        ),
      ),
    );
  }

  // (Section 4: HomePage Hero Banner)
  Widget _buildBannerCard(BuildContext context, AppPackage app) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return RepaintBoundary(
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.0),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  AppDetailsPage(app: app),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation
                      .drive(CurveTween(curve: Curves.easeInOutExpo)),
                  child: SlideTransition(
                    position: animation.drive(Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeInOutExpo))),
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          ),
          child: SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 上半部分：宣传图
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: (app.screenshots != null && app.screenshots!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: app.screenshots![0],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: colorScheme.surfaceContainerHigh,
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                                errorWidget: (c, e, s) => Container(
                                  color: colorScheme.surfaceContainerHigh,
                                  child: Icon(Icons.image_rounded, size: 48, color: colorScheme.primary.withValues(alpha: 0.2)),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [colorScheme.primaryContainer, colorScheme.tertiaryContainer],
                                  ),
                                ),
                                child: Icon(Icons.image_rounded, size: 48, color: colorScheme.primary.withValues(alpha: 0.2)),
                              ),
                      ),
                      // 渐变蒙层
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
                              stops: const [0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // 悬浮源标签
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _buildTrustLabel(app.primarySource),
                      ),
                    ],
                  ),
                ),
                // 下半部分：应用信息
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'app-icon-banner-${app.name}',
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(14.0),
                          ),
                          child: app.icon != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14.0),
                                  child: CachedNetworkImage(imageUrl: app.icon!, fit: BoxFit.cover),
                                )
                              : Center(
                                  child: Text(
                                    app.name[0].toUpperCase(),
                                    style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 20),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.4),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              app.description,
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEssentialCard(dynamic item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = item['name'] as String;
    final source = item['source'] as String? ?? 'Native';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _executeInstall(name, source),
          borderRadius: BorderRadius.circular(20.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Icon(Icons.extension_rounded,
                      size: 20, color: colorScheme.onSecondaryContainer),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['description'] ?? "",
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.add_circle_outline_rounded,
                    color: colorScheme.primary, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // (Section 7: AI Recommendation Section)
  Widget _buildAIPickSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      constraints: const BoxConstraints(minHeight: 100, maxHeight: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.tertiary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome_rounded, size: 16, color: colorScheme.onTertiary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.aiPickDay,
                    style: TextStyle(fontWeight: FontWeight.w900, color: colorScheme.tertiary, fontSize: 16),
                  ),
                  Text(
                    l10n.aiPickDaySubtitle,
                    style: TextStyle(fontSize: 11, color: colorScheme.onTertiaryContainer.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: MarkdownBody(
              data: _aiPickBlurb!.split('PICK_JSON:')[0],
              shrinkWrap: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(fontSize: 14, height: 1.6, color: colorScheme.onSurface, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AIAppResolver(aiText: _aiPickBlurb!, jsonPrefix: 'PICK_JSON:'),
        ],
      ),
    );
  }

  Widget _buildTrustLabel(String source) {
    final colorScheme = Theme.of(context).colorScheme;
    String label = "社区";
    Color color = Colors.orange;
    IconData icon = Icons.people_rounded;

    if (source == "Pacman" || source == "Native") {
      label = "官方";
      color = Colors.blue;
      icon = Icons.verified_user_rounded;
    } else if (source == "Flatpak") {
      label = "经校验";
      color = Colors.green;
      icon = Icons.verified_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  void _executeInstall(String name, String source) {
    BackendService.instance
        .executeAction("-I", name, source)
        .listen((event) {
      // 进度和状态由 BackendService 的 ValueNotifier 自动同步到全局 UI
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("正在安装 $name..."),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }


}
