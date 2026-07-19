import 'package:collection/collection.dart';
import "package:frontend/data/repositories/ai_repository.dart";
import "package:frontend/data/repositories/package_repository.dart";
import "package:provider/provider.dart";
import "package:frontend/features/explore/presentation/controllers/browse_controller.dart";
import "package:flutter/material.dart";
import 'package:file_picker/file_picker.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/services/category_service.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/features/home/widgets/category_quick_access.dart';
import 'package:frontend/features/home/widgets/ai_pick_section.dart';
import 'package:frontend/features/home/widgets/hero_section.dart';
import 'package:frontend/features/home/widgets/import_packages_dialog.dart';
import 'package:frontend/core/widgets/section_header.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'package:frontend/features/home/widgets/dynamic_app_section.dart';

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
  String? _aiPickBlurb;
  bool _isAILoading = false;
  // ⚡ Bolt: Memoize categories to avoid redundant allocations and L10n lookups on every build
  List<CategoryItem> _categories = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAIPick());
  }

  @override
  void dispose() {
    _heroScrollController.dispose();
    _quickAccessScrollController.dispose();
    _hotAppsScrollController.dispose();
    _forYouScrollController.dispose();
    // Murphy-proof: Clear shelf controllers to prevent memory leaks
    for (final controller in _shelfControllers.values) {
      controller.dispose();
    }
    _shelfControllers.clear();
    super.dispose();
  }

  Future<void> _refresh() async {
    final browse = context.read<BrowseController>();
    await browse.fetchRecommendations(forceRefresh: true);
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

    final taskController = context.read<TaskController>();
    if (taskController.isBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.taskInProgress),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

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
          builder: (context) => ImportPackagesDialog(
            packagesCount: packages.length,
            titleText: l10n.importPackages,
            contentText: l10n.importPackagesConfirm(packages.length),
            cancelText: l10n.cancel,
            confirmText: l10n.allDownloads,
            onCancel: () => Navigator.pop(context),
            onConfirm: () async {
              Navigator.pop(context);

              // Capture context properties before async gaps
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final appLocalizations = AppLocalizations.of(context);

              if (appLocalizations == null) return;

              for (var pkg in packages) {
                if (!mounted) break;

                final name = pkg['name'] as String;
                final source = pkg['source'] as String? ?? 'Native';

                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(appLocalizations.installingPkg(name)),
                    duration: const Duration(seconds: 4),
                  ),
                );

                await taskController.runTask(
                  "-I",
                  name,
                  source,
                  appLocalizations,
                );
              }
            },
          ),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _categories = CategoryService.getCategories(context);
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
                shouldRebuild: (prev, next) =>
                    !const IterableEquality().equals(prev, next),
                builder: (context, featured, _) {
                  return SmoothSizeSwitcher(
                    alignment: Alignment.topCenter,
                    child: featured.isEmpty
                        ? const SizedBox.shrink(key: ValueKey('empty_hero'))
                        : HeroSection(
                            key: const ValueKey('hero_section'),
                            apps: featured,
                            scrollController: _heroScrollController,
                          ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Selector<SettingsController, bool>(
                selector: (context, settings) => settings.isAIEnabled,
                builder: (context, isAIEnabled, _) {
                  if (!isAIEnabled) return const SizedBox.shrink();
                  return SmoothSizeSwitcher(
                    alignment: Alignment.topCenter,
                    child: _isAILoading
                        ? const Column(
                            key: ValueKey('ai_skeleton_wrapper'),
                            children: [
                              SizedBox(height: 32),
                              AIPickSkeleton(),
                            ],
                          )
                        : Column(
                            key: const ValueKey('ai_content_wrapper'),
                            children: [
                              const SizedBox(height: 32),
                              AIPickSection(
                                aiPickBlurb:
                                    _aiPickBlurb ??
                                    '暂时无法生成个性化推荐。你仍可浏览编辑精选，或稍后重试。',
                                isFallback: _aiPickBlurb == null,
                                onRefresh: _fetchAIPick,
                              ),
                            ],
                          ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  SectionHeader(title: l10n.categories),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            CategoryQuickAccess(
              categories: _categories,
              scrollController: _quickAccessScrollController,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 32, bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SectionHeader(
                        title: '快速开始',
                        subtitle: '从列表导入你常用的软件包',
                      ),
                    ),
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
              child: DynamicAppSection(
                recommendationKey: 'trending',
                emptyKey: const ValueKey('empty_trending'),
                emptyMessage: '暂无热门数据；网络恢复后会自动更新。',
                shelfKey: const ValueKey('trending_shelf'),
                title: l10n.hotApps,
                scrollController: _hotAppsScrollController,
              ),
            ),
            SliverToBoxAdapter(
              child: DynamicAppSection(
                recommendationKey: 'for_you',
                emptyKey: const ValueKey('empty_forYou'),
                emptyMessage: '继续搜索或安装应用后，这里会显示个性化建议。',
                shelfKey: const ValueKey('forYou_shelf'),
                title: l10n.forYou,
                scrollController: _forYouScrollController,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }
}
