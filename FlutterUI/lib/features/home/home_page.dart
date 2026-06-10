import "package:frontend/data/repositories/task_repository.dart";
import "package:frontend/data/repositories/ai_repository.dart";
import "package:frontend/data/repositories/package_repository.dart";
import "package:provider/provider.dart";
import "package:frontend/core/navigation_controller.dart";
import "package:frontend/features/explore/presentation/controllers/browse_controller.dart";
import "package:frontend/features/explore/presentation/pages/details_page.dart";
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/services/category_service.dart';
import 'package:frontend/widgets/ai_app_resolver.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';
import 'package:frontend/core/widgets/skeleton.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _aiPickBlurb;
  bool _isAILoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAIPick());
  }

  Future<void> _refresh() async {
    final browse = context.read<BrowseController>();
    await browse.fetchRecommendations();
    await _fetchAIPick();
  }

  Future<void> _fetchAIPick() async {
    final settings = context.read<SettingsController>();
    if (!settings.isAIEnabled) return;

    setState(() => _isAILoading = true);
    try {
      final aiRepo = context.read<AIRepository>();
      final pick = await aiRepo.aiPickOfTheDay();
      if (mounted) {
        setState(() {
          // 过滤掉所有已知错误提示文本，隐藏 AI 推荐区块
          final errorPatterns = [
            '⚠', '⏱',
            'AI 服务', 'AI service',
            'timed out', '超时',
            '无法连接', 'Connection',
            '错误', 'error', 'Error',
            '未启用', 'not enabled',
            'failed', 'Failed',
            'Today\'s recommendation: OmniStore',
          ];
          final isError = errorPatterns.any(
            (p) => pick.toLowerCase().contains(p.toLowerCase()),
          );
          _aiPickBlurb = isError ? null : pick;
          _isAILoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isAILoading = false);
    }
  }

  Future<void> _importPackages() async {
    final l10n = AppLocalizations.of(context)!;
    final packageRepo = context.read<PackageRepository>();
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'json'],
    );

    if (!mounted) return;

    if (result != null) {
      final path = result.files.single.path!;
      final packages = await packageRepo.importPackages(path);
      if (mounted && packages.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.importPackages),
            content: Text(l10n.importPackagesConfirm(packages.length)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  for (var pkg in packages) {
                    final name = pkg['name'] as String;
                    final source = pkg['source'] as String? ?? 'Native';
                    _executeInstall(name, source);
                  }
                },
                child: Text(l10n.allDownloads),
              ),
            ],
          ),
        );
      }
    }
  }

  void _executeInstall(String name, String source) {
    context
        .read<TaskRepository>()
        .executeAction("-I", name, source)
        .listen((_) {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.installingPkg(name)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Consumer<BrowseController>(
                builder: (context, browse, _) {
                  final featured = browse.recommendations['featured'] ?? [];
                  return _buildHeroSection(featured);
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Consumer<SettingsController>(
                builder: (context, settings, _) {
                  if (!settings.isAIEnabled) return const SizedBox.shrink();
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isAILoading
                        ? _buildAIPickSkeleton(key: const ValueKey('ai_skeleton'))
                        : (_aiPickBlurb != null
                            ? _buildAIPickSection(key: const ValueKey('ai_content'))
                            : SizedBox.shrink(key: const ValueKey('ai_empty'))),
                  );
                },
              ),
            ),
            _buildCategoryQuickAccess(),
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
                        label: Text(l10n.importList),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Consumer<BrowseController>(
                builder: (context, browse, _) {
                  final trending = browse.recommendations['trending'] ?? [];
                  return _buildCategoryShelf(l10n.hotApps, trending);
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Consumer<BrowseController>(
                builder: (context, browse, _) {
                  final forYou = browse.recommendations['for_you'] ?? [];
                  if (forYou.isEmpty) return const SizedBox.shrink();
                  return _buildCategoryShelf(l10n.forYou, forYou);
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(List<AppPackage> apps) {
    if (apps.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionHeader(AppLocalizations.of(context)!.featured),
        const SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: apps.length,
            separatorBuilder: (context, index) => const SizedBox(width: 20),
            itemBuilder: (context, index) => _buildBannerCard(apps[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerCard(AppPackage app) {
    final theme = Theme.of(context);
    final screenshot = (app.screenshots != null && app.screenshots!.isNotEmpty)
        ? app.screenshots!.first
        : null;
    final heroTag = 'hero-banner-${app.name}-${app.primarySource}';

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppDetailsPage(app: app, heroTag: heroTag),
          ),
        ),
        child: Container(
          width: 440,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
          ),
          child: Stack(
            children: [
              if (screenshot != null)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: screenshot,
                    fit: BoxFit.cover,
                    memCacheWidth: 880,
                    errorWidget: (c, e, s) => const Icon(Icons.image, size: 48),
                  ),
                )
              else
                Center(
                  child: Icon(
                    Icons.apps_rounded,
                    size: 80,
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 20,
                right: 20,
                child: Row(
                  children: [
                    Hero(
                      tag: heroTag,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: app.icon != null
                            ? CachedNetworkImage(
                                imageUrl: app.icon!,
                                fit: BoxFit.cover,
                                memCacheWidth: 108,
                                memCacheHeight: 108,
                                errorWidget: (c, e, s) =>
                                    const Icon(Icons.apps, color: Colors.black),
                              )
                            : const Icon(Icons.apps, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            app.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            app.description,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
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
    );
  }

  Widget _buildCategoryShelf(String title, List<AppPackage> apps) {
    if (apps.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        _buildSectionHeader(title),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: apps.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final app = apps[index];
              final heroTag = 'app-shelf-${app.name}-${app.primarySource}';
              return SizedBox(
                width: 130,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AppDetailsPage(app: app, heroTag: heroTag),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      Hero(
                        tag: heroTag,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: app.icon != null
                              ? CachedNetworkImage(
                                  imageUrl: app.icon!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 200,
                                  memCacheHeight: 200,
                                  errorWidget: (c, e, s) =>
                                      const Icon(Icons.apps),
                                )
                              : const Icon(Icons.apps, size: 40),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          app.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryQuickAccess() {
    final categories = CategoryService.getCategories(context);
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              label: 'Category: ${categories[index].name}',
              child: ActionChip(
                avatar: Icon(categories[index].icon, size: 18),
                label: Text(categories[index].name),
                tooltip: categories[index].name,
                onPressed: () {
                  final browse = context.read<BrowseController>();
                  browse.pendingSearchQuery =
                      '/${categories[index].id.toLowerCase()}';
                  context.read<NavigationController>().setIndex(2);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(title, style: OmnistoreTheme.standardHeader(context)),
    );
  }

  Widget _buildAIPickSkeleton({Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(width: 24, height: 24, borderRadius: 12),
              SizedBox(width: 8),
              Skeleton(width: 140, height: 16),
            ],
          ),
          SizedBox(height: 16),
          Skeleton(width: double.infinity, height: 14),
          SizedBox(height: 8),
          Skeleton(width: 240, height: 14),
          SizedBox(height: 16),
          Skeleton(width: 120, height: 36, borderRadius: 18),
        ],
      ),
    );
  }

  Widget _buildAIPickSection({Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.tertiaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.aiPickDay,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MarkdownBody(data: _aiPickBlurb ?? ""),
          const SizedBox(height: 12),
          AIAppResolver(aiText: _aiPickBlurb ?? "", jsonPrefix: "PICK_JSON:"),
        ],
      ),
    );
  }
}
