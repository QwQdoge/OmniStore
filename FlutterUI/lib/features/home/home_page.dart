import "package:frontend/data/repositories/task_repository.dart";
import "package:frontend/data/repositories/ai_repository.dart";
import "package:frontend/data/repositories/package_repository.dart";
import "package:provider/provider.dart";
import "package:frontend/features/explore/presentation/controllers/browse_controller.dart";
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/services/category_service.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/features/home/widgets/app_shelf.dart';
import 'package:frontend/features/home/widgets/hero_section.dart';
import 'package:frontend/features/home/widgets/category_quick_access.dart';
import 'package:frontend/features/home/widgets/ai_pick_section.dart';
import 'package:frontend/features/home/widgets/section_header.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _heroScrollController = ScrollController();
  final ScrollController _quickAccessScrollController = ScrollController();
  final ScrollController _hotAppsScrollController = ScrollController();
  final ScrollController _forYouScrollController = ScrollController();
  // ignore: unused_field
  final Map<String, ScrollController> _shelfControllers = {};
  List<CategoryItem> _categories = [];
  String? _aiPickBlurb;
  bool _isAILoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAIPick());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Memoize localized categories to avoid re-generating them on every build
    _categories = CategoryService.getCategories(context);
  }

  @override
  void dispose() {
    _heroScrollController.dispose();
    _quickAccessScrollController.dispose();
    _hotAppsScrollController.dispose();
    _forYouScrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final browse = context.read<BrowseController>();
    await browse.fetchRecommendations();
    if (!mounted) return;
    await _fetchAIPick();
  }

  Future<void> _fetchAIPick() async {
    if (!mounted) return;
    final settings = context.read<SettingsController>();
    if (!settings.isAIEnabled) return;

    setState(() => _isAILoading = true);
    try {
      final aiRepo = context.read<AIRepository>();
      final pick = await aiRepo.aiPickOfTheDay();
      if (!mounted) return;
      setState(() {
        // 过滤掉所有已知错误提示文本，隐藏 AI 推荐区块
        final errorPatterns = [
          '⚠',
          '⏱',
          'AI 服务',
          'AI service',
          'timed out',
          '超时',
          '无法连接',
          'Connection',
          '错误',
          'error',
          'Error',
          '未启用',
          'not enabled',
          'failed',
          'Failed',
          'Today\'s recommendation: OmniStore',
        ];
        final isError = errorPatterns.any(
          (p) => pick.toLowerCase().contains(p.toLowerCase()),
        );
        _aiPickBlurb = isError ? null : pick;
        _isAILoading = false;
      });
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
      if (!mounted) return;

      if (packages.isNotEmpty) {
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
              child: Selector<BrowseController, List<AppPackage>>(
                selector: (context, browse) =>
                    browse.recommendations['featured'] ?? [],
                builder: (context, featured, _) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: featured.isEmpty
                        ? const SizedBox.shrink(key: ValueKey('empty_hero'))
                        : _buildHeroSection(featured, key: const ValueKey('hero_section')),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Selector<SettingsController, bool>(
                selector: (context, settings) => settings.isAIEnabled,
                builder: (context, isAIEnabled, _) {
                  if (!isAIEnabled) return const SizedBox.shrink();
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isAILoading
                        ? const AIPickSkeleton(key: ValueKey('ai_skeleton'))
                        : (_aiPickBlurb != null
                              ? AIPickSection(
                                  key: const ValueKey('ai_content'),
                                  aiPickBlurb: _aiPickBlurb!,
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('ai_empty'),
                                )),
                  );
                },
              ),
            ),
            CategoryQuickAccess(
              categories: _categories,
              scrollController: _quickAccessScrollController,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 40, bottom: 16),
                child: Row(
                  children: [
                    Expanded(child: SectionHeader(title: l10n.essentialTools)),
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
              child: Selector<BrowseController, List<AppPackage>>(
                selector: (context, browse) =>
                    browse.recommendations['trending'] ?? [],
                builder: (context, trending, _) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: trending.isEmpty
                        ? const SizedBox.shrink(key: ValueKey('empty_trending'))
                        : AppShelf(
                            key: const ValueKey('trending_shelf'),
                            title: l10n.hotApps,
                            apps: trending,
                            scrollController: _hotAppsScrollController,
                          ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Selector<BrowseController, List<AppPackage>>(
                selector: (context, browse) =>
                    browse.recommendations['for_you'] ?? [],
                builder: (context, forYou, _) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: forYou.isEmpty
                        ? const SizedBox.shrink(key: ValueKey('empty_forYou'))
                        : AppShelf(
                            key: const ValueKey('forYou_shelf'),
                            title: l10n.forYou,
                            apps: forYou,
                            scrollController: _forYouScrollController,
                          ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(List<AppPackage> apps, {Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionHeader(AppLocalizations.of(context)!.featured),
        const SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: Scrollbar(
            controller: _heroScrollController,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _heroScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: apps.length,
              separatorBuilder: (context, index) => const SizedBox(width: 20),
              itemBuilder: (context, index) => BannerCard(app: apps[index]),
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildCategoryQuickAccess() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 66,
        child: Scrollbar(
          controller: _quickAccessScrollController,
          thumbVisibility: true,
          child: ListView.builder(
            controller: _quickAccessScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: _categories.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                label: 'Category: ${_categories[index].name}',
                child: ActionChip(
                  avatar: Icon(_categories[index].icon, size: 18),
                  label: Text(_categories[index].name),
                  tooltip: _categories[index].name,
                  onPressed: () {
                    final browse = context.read<BrowseController>();
                    browse.pendingSearchQuery =
                        '/${_categories[index].id.toLowerCase()}';
                    context.read<NavigationController>().setIndex(2);
                  },
                ),
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
