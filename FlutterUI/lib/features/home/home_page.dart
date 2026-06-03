import "package:frontend/data/repositories/task_repository.dart";
import "package:frontend/data/repositories/ai_repository.dart";
import "package:frontend/data/repositories/package_repository.dart";
import "package:provider/provider.dart";
import "package:frontend/core/navigation_controller.dart";
import "package:frontend/features/explore/presentation/controllers/browse_controller.dart";
import "package:frontend/features/explore/presentation/pages/details_page.dart";
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/services/category_service.dart';
import 'package:frontend/widgets/ai_app_resolver.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';

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
          _aiPickBlurb = pick;
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
    FilePickerResult? result = await FilePicker.platform.pickFiles(
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
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final browse = context.watch<BrowseController>();
    final settings = context.watch<SettingsController>();

    final featured = browse.recommendations['featured'] ?? [];
    final trending = browse.recommendations['trending'] ?? [];
    final forYou = browse.recommendations['for_you'] ?? [];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeroSection(featured)),
            if (settings.isAIEnabled)
              SliverToBoxAdapter(
                child: _isAILoading
                    ? Container(
                        margin: const EdgeInsets.all(20),
                        height: 100,
                        child: const Center(child: CircularProgressIndicator()),
                      )
                    : (_aiPickBlurb != null
                          ? _buildAIPickSection()
                          : const SizedBox.shrink()),
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
              child: _buildCategoryShelf(l10n.hotApps, trending),
            ),
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
    if (apps.isEmpty) return const SizedBox.shrink();
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
            itemCount: apps.length,
            separatorBuilder: (context, index) => const SizedBox(width: 20),
            itemBuilder: (context, index) => _buildBannerCard(apps[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerCard(AppPackage app) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AppDetailsPage(app: app)),
        ),
        child: SizedBox(
          width: 300,
          child: Column(
            children: [
              Expanded(
                child: app.icon != null
                    ? CachedNetworkImage(
                        imageUrl: app.icon!,
                        fit: BoxFit.cover,
                        errorWidget: (c, e, s) => const Icon(Icons.image),
                      )
                    : const Icon(Icons.image),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  app.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildSectionHeader(title),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: apps.length,
            itemBuilder: (context, index) => Container(
              width: 150,
              child: Card(
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppDetailsPage(app: apps[index]),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: apps[index].icon != null
                            ? CachedNetworkImage(
                                imageUrl: apps[index].icon!,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.apps),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          apps[index].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
            child: ActionChip(
              label: Text(categories[index].name),
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAIPickSection() {
    return Container(
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
