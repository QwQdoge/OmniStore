import "package:flutter/services.dart";
import "package:frontend/data/repositories/ai_repository.dart";
import "package:frontend/data/repositories/package_repository.dart";
import "package:frontend/services/backend_service.dart";
import "package:provider/provider.dart";
import "package:frontend/features/settings/presentation/controllers/settings_controller.dart";
import "package:frontend/features/task_manager/presentation/controllers/task_controller.dart";
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/models/task_state.dart';
import 'package:frontend/core/network/github_client.dart';
import 'package:frontend/widgets/smooth_progress_bar.dart';
import 'package:frontend/widgets/app_source_tag.dart';
import 'package:frontend/widgets/github_star_badge.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/features/explore/presentation/widgets/ai_dialogs.dart';
import 'package:frontend/features/explore/presentation/widgets/terminal_dialog.dart';
import 'package:frontend/features/explore/presentation/widgets/screenshot_viewer.dart';
import 'package:frontend/features/explore/presentation/widgets/action_dialogs.dart';

// Feature: Extract details page transition to a declarative router (e.g. GoRouter) to support deep-linking (e.g. omnistore://app/id).
// Feature: Implement Split-View layout for desktop/tablet sizes (List on left, Details on right).
class AppDetailsPage extends StatefulWidget {
  final AppPackage app;
  final String? heroTag;
  final bool isEmbedded;

  const AppDetailsPage({
    super.key,
    required this.app,
    this.heroTag,
    this.isEmbedded = false,
  });

  @override
  State<AppDetailsPage> createState() => _AppDetailsPageState();
}

class _AppDetailsPageState extends State<AppDetailsPage> {
  // Feature: Add strict accessibility Semantics wrappers around action buttons and icons.
  // Feature: Replace loading spinner with beautiful animated Skeleton loaders matching the card layout.
  late String _selectedSource;
  late bool _isAppInstalled;
  Map<String, dynamic>? _extraDetails;
  bool _isLoadingDetails = false;

  final ScrollController _screenshotScrollController = ScrollController();
  final ScrollController _variantScrollController = ScrollController();

  bool _hasCapability(String capability) {
    try {
      final sources = BackendService.availableSources.value;
      if (sources.isEmpty) return true;
      final cap = sources.firstWhere(
        (s) => s['name'] == _selectedSource,
        orElse: () => {},
      );
      if (cap.isEmpty) return true;
      return cap['capabilities']?[capability] ?? true;
    } catch (_) {
      return true;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.app.primarySource;
    _isAppInstalled = widget.app.installed;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchExtraDetails().then((_) {
        if (mounted) {
          _checkSourceSuggestion();
        }
      });
    });
  }

  @override
  void dispose() {
    _screenshotScrollController.dispose();
    _variantScrollController.dispose();
    super.dispose();
  }

  void _checkSourceSuggestion() {
    if (_selectedSource != "Flatpak" &&
        widget.app.sources.contains("Flatpak")) {
      if (!mounted || _isAppInstalled) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.flatpakBetterDesc),
          action: SnackBarAction(
            label: AppLocalizations.of(context)!.switchSource,
            onPressed: () {
              setState(() {
                _selectedSource = "Flatpak";
              });
            },
          ),
        ),
      );
    }
  }

  Future<void> _fetchExtraDetails() async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoadingDetails = true);
    final target = widget.app.id ?? widget.app.name;
    final packageRepo = context.read<PackageRepository>();
    final details = await packageRepo.getAppDetails(target);
    if (mounted) {
      setState(() {
        _extraDetails = details;
        _isLoadingDetails = false;
      });
    }
  }

  void _cancelAction() {
    context.read<TaskController>().cancelTask(AppLocalizations.of(context)!);
  }

  void _showTerminalDialog() {
    showDialog(context: context, builder: (ctx) => const TerminalDialog());
  }

  Future<void> _handleAction(String flag) async {
    final localizations = AppLocalizations.of(context)!;
    final taskController = context.read<TaskController>();
    if (taskController.isBusy) {
      return;
    }

    final isUninstall = flag == "-R";
    bool cleanOrphans = false;

    final cleanOrphansResult = await showDialog<bool?>(
      context: context,
      builder: (context) => ActionConfirmDialog(
        isUninstall: isUninstall,
        appName: widget.app.name,
        selectedSource: _selectedSource,
      ),
    );

    if (cleanOrphansResult == null) {
      return;
    }

    cleanOrphans = cleanOrphansResult;

    if (_selectedSource == "AUR" && mounted) {
      final aurConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => const AurSecurityDialog(),
      );
      if (aurConfirmed != true) {
        return;
      }
    }

    final variantMap = _getVariantForSource(_selectedSource);
    String? variantId = variantMap?['id']?.toString();
    if (variantId == null || variantId.isEmpty) {
      try {
        final v = widget.app.variants.firstWhere(
          (v) => v.source == _selectedSource,
        );
        variantId = v.id;
      } catch (_) {}
    }
    final String targetIdentifier = (variantId != null && variantId.isNotEmpty)
        ? variantId
        : widget.app.name;

    final taskFlag = isUninstall && cleanOrphans ? "-Rsn" : flag;
    await taskController.runTask(
      taskFlag,
      targetIdentifier,
      _selectedSource,
      localizations,
      url: widget.app.url,
    );

    if (mounted) {
      setState(() {
        if (flag == "-I") {
          _isAppInstalled = true;
        }
        if (flag == "-R") {
          _isAppInstalled = false;
        }
      });
    }
  }

  Widget _buildMainContent(BuildContext context, ColorScheme colorScheme, ThemeData theme, TaskController task, SettingsController settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme),
        const SizedBox(height: 24),
        _buildActionArea(colorScheme, task),
        const SizedBox(height: 32),
        const Divider(),
        _buildSectionTitle(theme, AppLocalizations.of(context)!.about),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isLoadingDetails
              ? const Column(
                  key: ValueKey('loading'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: double.infinity, height: 14),
                    SizedBox(height: 8),
                    Skeleton(width: double.infinity, height: 14),
                    SizedBox(height: 8),
                    Skeleton(width: 200, height: 14),
                  ],
                )
              : MarkdownBody(
                  key: const ValueKey('loaded'),
                  data:
                      _extraDetails?['description'] ??
                      (widget.app.description.isEmpty
                          ? AppLocalizations.of(context)!.noResults
                          : widget.app.description),
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: theme.textTheme.bodyLarge,
                  ),
                ),
        ),
        const SizedBox(height: 24),
        if (_hasCapability('has_screenshots') &&
            _extraDetails != null &&
            _extraDetails!['screenshots'] != null &&
            (_extraDetails!['screenshots'] as List).isNotEmpty) ...[
          _buildSectionTitle(
            theme,
            AppLocalizations.of(context)!.screenshots,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 236,
            child: Scrollbar(
              controller: _screenshotScrollController,
              thumbVisibility: true,
              child: ListView.separated(
                controller: _screenshotScrollController,
                padding: const EdgeInsets.only(bottom: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount:
                    (_extraDetails!['screenshots'] as List).length,
                separatorBuilder: (context, _) =>
                    const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final imageUrl = _extraDetails!['screenshots'][index];
                  return Hero(
                    tag: 'screenshot-$imageUrl',
                    child: Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _showScreenshotViewer(imageUrl),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 360,
                          fit: BoxFit.cover,
                          memCacheWidth: 720,
                          placeholder: (context, url) => const Skeleton(
                            width: 360,
                            height: 220,
                            borderRadius: 20.0,
                          ),
                          errorWidget: (context, url, error) =>
                              Container(
                                width: 360,
                                color:
                                    colorScheme.surfaceContainerHighest,
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                ),
                              ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
        _buildSectionTitle(
          theme,
          AppLocalizations.of(context)!.details,
        ),
        _buildInfoRow(
          Icons.source_rounded,
          AppLocalizations.of(context)!.source,
          widget.app.primarySource,
        ),
        _buildInfoRow(
          Icons.all_inclusive_rounded,
          AppLocalizations.of(context)!.variant,
          widget.app.sources.join(", "),
        ),
        _buildInfoRow(
          Icons.verified_rounded,
          AppLocalizations.of(context)!.version,
          widget.app.version,
        ),
        if (_extraDetails?['developer'] != null)
          _buildInfoRow(
            Icons.person_rounded,
            AppLocalizations.of(context)!.developer,
            _extraDetails!['developer'],
          ),
        if (_extraDetails?['license'] != null)
          _buildInfoRow(
            Icons.description_rounded,
            AppLocalizations.of(context)!.license,
            _extraDetails!['license'],
          ),
        _buildDependencySection(theme),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = context.watch<SettingsController>();

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            title: Text(
              widget.app.name,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            leading: widget.isEmbedded ? null : Semantics(
              label: 'Back',
              hint: 'Go back to the previous screen',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              if (widget.app.url != null && widget.app.url!.isNotEmpty)
                Semantics(
                  label: AppLocalizations.of(context)!.visitWebsite,
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.language_rounded),
                    tooltip: AppLocalizations.of(context)!.visitWebsite,
                    onPressed: () async {
                      final uri = Uri.parse(widget.app.url!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                ),
              if (settings.isAIEnabled) ...[
                Semantics(
                  label: AppLocalizations.of(context)!.aiPromptExplain,
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.auto_awesome_rounded),
                    tooltip: AppLocalizations.of(context)!.aiPromptExplain,
                    onPressed: _showAIExplainDialog,
                  ),
                ),
                if (widget.app.variants.length > 1)
                  Semantics(
                    label: AppLocalizations.of(context)!.aiCompareTitle,
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.compare_arrows_rounded),
                      tooltip: AppLocalizations.of(context)!.aiCompareTitle,
                      onPressed: _showAICompareDialog,
                    ),
                  ),
                Semantics(
                  label: AppLocalizations.of(context)!.aiCliTitle,
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.terminal_rounded),
                    tooltip: AppLocalizations.of(context)!.aiCliTitle,
                    onPressed: _showAICliDialog,
                  ),
                ),
                Semantics(
                  label: AppLocalizations.of(context)!.aiConflictTitle,
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.report_problem_rounded),
                    tooltip: AppLocalizations.of(context)!.aiConflictTitle,
                    onPressed: _showAIConflictDialog,
                  ),
                ),
              ],
              Semantics(
                label: AppLocalizations.of(context)!.terminalOutput,
                button: true,
                child: IconButton(
                  icon: Selector<TaskController, bool>(
                    selector: (context, tc) => tc.isBusy,
                    builder: (context, isBusy, child) => Badge(
                      isLabelVisible: isBusy,
                      child: const Icon(Icons.terminal_rounded),
                    ),
                  ),
                  tooltip: AppLocalizations.of(context)!.terminalOutput,
                  onPressed: _showTerminalDialog,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
        body: SelectionArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Header metadata and primary actions
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(theme),
                            const SizedBox(height: 24),
                            Consumer<TaskController>(
                              builder: (context, task, _) =>
                                  _buildActionArea(colorScheme, task),
                            ),
                            const SizedBox(height: 32),
                            _buildSectionTitle(
                              theme,
                              AppLocalizations.of(context)!.details,
                            ),
                            _buildInfoRow(
                              Icons.source_rounded,
                              AppLocalizations.of(context)!.source,
                              widget.app.primarySource,
                            ),
                            _buildInfoRow(
                              Icons.all_inclusive_rounded,
                              AppLocalizations.of(context)!.variant,
                              widget.app.sources.join(", "),
                            ),
                            _buildInfoRow(
                              Icons.verified_rounded,
                              AppLocalizations.of(context)!.version,
                              widget.app.version,
                            ),
                            if (_extraDetails?['developer'] != null)
                              _buildInfoRow(
                                Icons.person_rounded,
                                AppLocalizations.of(context)!.developer,
                                _extraDetails!['developer'],
                              ),
                            if (_extraDetails?['license'] != null)
                              _buildInfoRow(
                                Icons.description_rounded,
                                AppLocalizations.of(context)!.license,
                                _extraDetails!['license'],
                              ),
                            _buildDependencySection(theme),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      // Right Column: Screenshots, About and details
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle(theme, AppLocalizations.of(context)!.about),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _isLoadingDetails
                                  ? const Column(
                                      key: ValueKey('loading'),
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Skeleton(width: double.infinity, height: 14),
                                        SizedBox(height: 8),
                                        Skeleton(width: double.infinity, height: 14),
                                        SizedBox(height: 8),
                                        Skeleton(width: 200, height: 14),
                                      ],
                                    )
                                  : MarkdownBody(
                                      key: const ValueKey('loaded'),
                                      data:
                                          _extraDetails?['description'] ??
                                          (widget.app.description.isEmpty
                                              ? AppLocalizations.of(context)!.noResults
                                              : widget.app.description),
                                      selectable: true,
                                      styleSheet: MarkdownStyleSheet(
                                        p: theme.textTheme.bodyLarge,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 24),
                            if (_hasCapability('has_screenshots') &&
                                _extraDetails != null &&
                                _extraDetails!['screenshots'] != null &&
                                (_extraDetails!['screenshots'] as List).isNotEmpty) ...[
                              _buildSectionTitle(
                                theme,
                                AppLocalizations.of(context)!.screenshots,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 236,
                                child: Scrollbar(
                                  controller: _screenshotScrollController,
                                  thumbVisibility: true,
                                  child: ListView.separated(
                                    controller: _screenshotScrollController,
                                    padding: const EdgeInsets.only(bottom: 16),
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount:
                                        (_extraDetails!['screenshots'] as List).length,
                                    separatorBuilder: (context, _) =>
                                        const SizedBox(width: 16),
                                    itemBuilder: (context, index) {
                                      final imageUrl = _extraDetails!['screenshots'][index];
                                      return Hero(
                                        tag: 'screenshot-$imageUrl',
                                        child: Card(
                                          elevation: 0,
                                          margin: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20.0),
                                            side: BorderSide(
                                              color: colorScheme.outlineVariant.withValues(
                                                alpha: 0.5,
                                              ),
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                            onTap: () => _showScreenshotViewer(imageUrl),
                                            child: CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              width: 360,
                                              fit: BoxFit.cover,
                                              memCacheWidth: 720,
                                              placeholder: (context, url) => const Skeleton(
                                                width: 360,
                                                height: 220,
                                                borderRadius: 20.0,
                                              ),
                                              errorWidget: (context, url, error) =>
                                                  Container(
                                                    width: 360,
                                                    color:
                                                        colorScheme.surfaceContainerHighest,
                                                    child: const Icon(
                                                      Icons.broken_image_rounded,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : Consumer<TaskController>(
                    builder: (context, task, _) => _buildMainContent(
                      context,
                      colorScheme,
                      theme,
                      task,
                      settings,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchApp() async {
    final variant = _getVariantForSource(_selectedSource);
    String target = (variant?['id'] != null && _selectedSource == "Flatpak")
        ? variant!['id']!
        : widget.app.name.trim();
    final packageRepo = context.read<PackageRepository>();
    final success = await packageRepo.launchApp(target, _selectedSource);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.loadError)),
      );
    }
  }

  Future<void> _locateApp() async {
    final variant = _getVariantForSource(_selectedSource);
    String target = (variant?['id'] != null && _selectedSource == "Flatpak")
        ? variant!['id']!
        : widget.app.name.trim();
    final packageRepo = context.read<PackageRepository>();
    final success = await packageRepo.locateApp(target, _selectedSource);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.loadError)),
      );
    }
  }

  Widget _buildActionArea(ColorScheme colorScheme, TaskController task) {
    Widget content;
    if (task.isBusy) {
      content = Container(
        key: const ValueKey('busy'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: SmoothProgressBar(
          taskState: TaskState(
            id: "active",
            packageName: widget.app.name,
            status: TaskStatus.downloading,
            progress: task.progress ?? 0.0,
            stage: task.status,
            speed: task.speed,
          ),
          onCancel: _cancelAction,
        ),
      );
    } else if (_isAppInstalled) {
      content = Row(
        key: const ValueKey('installed'),
        children: [
          Semantics(
            label: AppLocalizations.of(context)!.locateInstallation,
            button: true,
            child: IconButton.filledTonal(
              onPressed: _locateApp,
              icon: const Icon(Icons.folder_open_rounded),
              tooltip: AppLocalizations.of(context)!.locateInstallation,
              style: IconButton.styleFrom(
                minimumSize: const Size(56, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 56,
              child: Semantics(
                label: AppLocalizations.of(context)!.uninstall,
                button: true,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(
                      color: colorScheme.error.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                  ),
                  onPressed: () => _handleAction("-R"),
                  child: Text(
                    AppLocalizations.of(context)!.uninstall,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 56,
              child: Semantics(
                label: AppLocalizations.of(context)!.launch,
                button: true,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                  ),
                  onPressed: _launchApp,
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: Text(
                    AppLocalizations.of(context)!.launch,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      content = SizedBox(
        key: const ValueKey('install'),
        width: double.infinity,
        height: 56,
        child: Semantics(
          label: AppLocalizations.of(context)!.install,
          button: true,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
            onPressed: () => _handleAction("-I"),
            icon: const Icon(Icons.download_rounded),
            label: Text(
              AppLocalizations.of(context)!.install,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: content,
    );
  }

  String? get _githubRepositoryUrl {
    final candidates = <String?>[
      widget.app.url,
      widget.app.homepage,
      _extraDetails?['url'] as String?,
      _extraDetails?['homepage'] as String?,
    ];
    for (final candidate in candidates) {
      if (candidate != null && GitHubClient.parseUrl(candidate) != null) {
        return candidate;
      }
    }
    return null;
  }

  Map<String, dynamic>? _getVariantForSource(String source) {
    if (_extraDetails != null && _extraDetails!['variants'] != null) {
      for (var v in _extraDetails!['variants']) {
        if (v['source'] == source) {
          return v;
        }
      }
    }
    return null;
  }

  Widget _buildHeader(ThemeData theme) {
    final iconUrl = widget.app.icon ?? _extraDetails?['icon'];
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Hero(
          tag:
              widget.heroTag ??
              'app-icon-${widget.app.name}-${widget.app.primarySource}',
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16.0),
            ),
            alignment: Alignment.center,
            child: iconUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: CachedNetworkImage(
                      imageUrl: iconUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 200,
                      memCacheHeight: 200,
                      placeholder: (context, url) => const Skeleton(
                        width: 100,
                        height: 100,
                        borderRadius: 24.0,
                      ),
                    ),
                  )
                : Text(
                    widget.app.name[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 48,
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.app.name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: AppLocalizations.of(context)!.copyName,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.app.name));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!.nameCopied,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_githubRepositoryUrl != null &&
                      _hasCapability('has_rating'))
                    GitHubStarBadge(
                      client: context.read<GitHubClient>(),
                      repositoryUrl: _githubRepositoryUrl,
                    ),
                  if (_isAppInstalled)
                    AppSourceTag(
                      source: _selectedSource,
                      mode: AppSourceTagMode.ready,
                    ),
                  AppSourceTag(
                    source: _selectedSource,
                    mode: AppSourceTagMode.trust,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_hasCapability('has_versions'))
                Scrollbar(
                  controller: _variantScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _variantScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SegmentedButton<String>(
                      segments:
                          <String>{
                            for (var v in widget.app.variants) v.source,
                            if (_extraDetails != null &&
                                _extraDetails!['variants'] != null)
                              for (var v in _extraDetails!['variants'])
                                v['source'].toString(),
                            _selectedSource,
                          }.map((String source) {
                            final version = _getVersionForSource(source);
                            return ButtonSegment<String>(
                              value: source,
                              label: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      source,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (version != null)
                                      Text(
                                        "v$version",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              icon: _getSourceIcon(source),
                            );
                          }).toList(),
                      selected: {_selectedSource},
                      onSelectionChanged: (Set<String> newSelection) {
                        final newValue = newSelection.first;
                        setState(() {
                          _selectedSource = newValue;
                          _isAppInstalled = _isSourceInstalled(newValue);
                        });
                      },
                      showSelectedIcon: false,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 16),
      child: Text(title, style: OmnistoreTheme.standardHeader(context)),
    );
  }

  String? _getVersionForSource(String source) {
    if (_extraDetails != null && _extraDetails!['variants'] != null) {
      for (var v in _extraDetails!['variants']) {
        if (v['source'] == source) {
          return v['version'] ?? v['last_version'];
        }
      }
    }
    for (var v in widget.app.variants) {
      if (v.source == source) {
        return v.version;
      }
    }
    return null;
  }

  bool _isSourceInstalled(String source) {
    if (_extraDetails != null && _extraDetails!['variants'] != null) {
      for (var v in _extraDetails!['variants']) {
        if (v['source'] == source) {
          return v['installed'] ?? false;
        }
      }
    }
    for (var v in widget.app.variants) {
      if (v.source == source) {
        return v.installed;
      }
    }
    return false;
  }

  Widget _buildDependencySection(ThemeData theme) {
    final variant = _getVariantForSource(_selectedSource);
    if (variant == null) {
      return const SizedBox.shrink();
    }
    final deps = variant['depends'] as List?;
    final dlSize = variant['download_size'];
    final insSize = variant['installed_size'];
    if ((deps == null || deps.isEmpty) && dlSize == null && insSize == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildSectionTitle(theme, AppLocalizations.of(context)!.installInfo),
        if (_hasCapability('has_size') && dlSize != null)
          _buildInfoRow(
            Icons.downloading_rounded,
            AppLocalizations.of(context)!.downloadSize,
            dlSize.toString(),
          ),
        if (_hasCapability('has_size') && insSize != null)
          _buildInfoRow(
            Icons.storage_rounded,
            AppLocalizations.of(context)!.installedSize,
            insSize.toString(),
          ),
        if (deps != null && deps.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.dependenciesCount(deps.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: deps
                .map(
                  (d) => Chip(
                    label: Text(
                      d.toString(),
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Future<void> _showAIExplainDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AIMarkdownDialog(
        title: AppLocalizations.of(context)!.aiPromptExplain,
        future: context.read<AIRepository>().aiExplain(
          widget.app.name,
          widget.app.description,
        ),
      ),
    );
  }

  Future<void> _showAICompareDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AIMarkdownDialog(
        title: AppLocalizations.of(context)!.aiCompareTitle,
        future: context.read<AIRepository>().aiCompareVariants(widget.app.name),
        width: 600,
        height: 450,
      ),
    );
  }

  Future<void> _showAICliDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AICliDialog(
        future: context.read<AIRepository>().aiGenerateCLI(
          widget.app.name,
          _selectedSource,
        ),
      ),
    );
  }

  Future<void> _showAIConflictDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AIMarkdownDialog(
        title: AppLocalizations.of(context)!.aiConflictTitle,
        future: context.read<AIRepository>().aiDetectConflicts(widget.app.name),
      ),
    );
  }

  Widget? _getSourceIcon(String source) {
    IconData? iconData;
    if (source == "Pacman" || source == "Native") {
      iconData = Icons.apps_rounded;
    } else if (source == "AUR") {
      iconData = Icons.cloud_outlined;
    } else if (source == "Flatpak") {
      iconData = Icons.inventory_2_outlined;
    } else if (source == "AppImage") {
      iconData = Icons.insert_drive_file_outlined;
    }
    if (iconData == null) {
      return null;
    }
    return Icon(iconData, size: 16);
  }

  void _showScreenshotViewer(String url) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => ScreenshotViewer(url: url),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
