import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import '../l10n/app_localizations.dart';
import '../services/app_package.dart';
import '../services/backend_service.dart';
import '../services/category_service.dart';
import '../widgets/magic_pulse_icon.dart';
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

  Future<void> _fetchAIPick() async {
    try {
      final pick = await BackendService.instance.aiPickOfTheDay();
      if (mounted) {
        setState(() {
          _aiPickBlurb = pick;
        });
      }
    } catch (_) {}
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
            if (_aiPickBlurb != null && _aiPickBlurb!.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildAIPickSection(),
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
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
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
              TextButton(onPressed: _refresh, child: const Text("重试")),
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

  Widget _buildShelfItem(BuildContext context, AppPackage app) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24.0),
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
                  tag: 'app-icon-${app.name}-${app.primarySource}',
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: app.icon != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16.0),
                            child: CachedNetworkImage(
                              imageUrl: app.icon!,
                              fit: BoxFit.cover,
                              errorWidget: (c, e, s) => Center(
                                child: Text(
                                  app.name[0].toUpperCase(),
                                  style: TextStyle(
                                      color: colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              app.name[0].toUpperCase(),
                              style: TextStyle(
                                  color: colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
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
                            fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        app.description,
                        style: TextStyle(
                            fontSize: 12, color: colorScheme.onSurfaceVariant),
                        maxLines: 2,
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchPage(initialQuery: 'category:${cat.id}'),
                      ),
                    );
                  },
                  avatar: Icon(cat.icon, size: 18, color: cat.color),
                  label: Text(cat.name),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  backgroundColor: colorScheme.surfaceContainerLow,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    // TODO: Centralize MD3 typography constants (e.g., 26px, w900, -0.8 letter spacing).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
        ),
      ),
    );
  }

  Widget _buildBannerCard(BuildContext context, AppPackage app) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return RepaintBoundary(
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: theme.brightness == Brightness.light
              ? colorScheme.surfaceContainerLow
              : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(28.0),
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
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28.0),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 上半部分：类似宣传大图
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primaryContainer,
                            colorScheme.tertiaryContainer,
                          ],
                        ),
                      ),
                      child: (app.screenshots != null &&
                              app.screenshots!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: app.screenshots![0],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(
                                  color:
                                      colorScheme.primary.withValues(alpha: 0.3),
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (c, e, s) => Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 48,
                                  color: colorScheme.primary.withValues(alpha: 0.5),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    colorScheme.primaryContainer,
                                    colorScheme.tertiaryContainer,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 48,
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                    ),
                  ),
                  // 下半部分：应用信息
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // 小图标
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: app.icon != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12.0),
                                  child: CachedNetworkImage(
                                    imageUrl: app.icon!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        const CircularProgressIndicator(
                                            strokeWidth: 2),
                                  ),
                                )
                              : Text(
                                  app.name[0].toUpperCase(),
                                          style: TextStyle(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    "Rating 4.${(app.name.length % 5) + 5} • ",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  _buildSourceChips(
                                      app.sources.take(2).toList()),
                                ],
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

  Widget _buildAIPickSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.withValues(alpha: 0.1), colorScheme.surfaceContainerLow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MagicPulseIcon(icon: Icons.auto_awesome_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.aiPickDay,
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.purple),
              ),
              const Spacer(),
              Text(
                l10n.aiPickDaySubtitle,
                style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _aiPickBlurb!,
            style: const TextStyle(fontSize: 14, height: 1.5, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustLabel(String source) {
    String label = "社区";
    Color color = Colors.orange;
    IconData icon = Icons.people_outline;

    if (source == "Pacman" || source == "Native") {
      label = "官方";
      color = Colors.blue;
      icon = Icons.verified_user_outlined;
    } else if (source == "Flatpak") {
      label = "经校验";
      color = Colors.green;
      icon = Icons.verified_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.bold)),
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
      SnackBar(content: Text("正在安装 $name...")),
    );
  }

  Widget _buildSourceChips(List<String> sources) {
    return Builder(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return Wrap(
        spacing: 6,
        children: sources
            .map(
              (s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
            .toList(),
      );
    });
  }
}
