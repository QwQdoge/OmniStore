import "package:frontend/data/repositories/ai_repository.dart";
import "package:frontend/data/repositories/package_repository.dart";
import "package:frontend/services/backend_service.dart";
import "package:provider/provider.dart";
import "package:frontend/features/settings/presentation/controllers/settings_controller.dart";
import "package:frontend/features/task_manager/presentation/controllers/task_controller.dart";
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/core/network/github_client.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/features/explore/presentation/widgets/ai_dialogs.dart';
import 'package:frontend/features/task_manager/presentation/widgets/terminal_dialog.dart';
import 'package:frontend/features/explore/presentation/widgets/screenshot_viewer.dart';
import 'package:frontend/features/explore/presentation/widgets/action_dialogs.dart';
import 'package:frontend/core/widgets/app_card.dart';

import 'package:frontend/features/explore/presentation/widgets/app_details_shared.dart';
import 'package:frontend/features/explore/presentation/widgets/app_details_header.dart';
import 'package:frontend/features/explore/presentation/widgets/app_details_actions.dart';
import 'package:frontend/features/explore/presentation/widgets/app_dependency_section.dart';
import 'package:frontend/features/explore/presentation/widgets/app_screenshots.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final taskController = context.read<TaskController>();
    if (taskController.isBusy) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.taskInProgress)));
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

    if (!mounted) return;

    if (cleanOrphansResult == null) {
      return;
    }

    cleanOrphans = cleanOrphansResult;

    if (_selectedSource == "AUR") {
      final aurConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => const AurSecurityDialog(),
      );
      if (!mounted || aurConfirmed != true) {
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
    final success = await taskController.runTask(
      taskFlag,
      targetIdentifier,
      _selectedSource,
      l10n,
      url: widget.app.url,
    );

    if (!mounted) return;

    setState(() {
      if (success) {
        if (flag == "-I") {
          _isAppInstalled = true;
        }
        if (flag == "-R") {
          _isAppInstalled = false;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(l10n.success),
              ],
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.failed),
            content: Text(
              "${taskController.status}\n\n${l10n.errorFatalStream("Check task logs for details")}",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        );
      }
    });
  }

  Widget _buildMainContent(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
    bool isAIEnabled,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDetailsHeader(
          app: widget.app,
          extraDetails: _extraDetails,
          selectedSource: _selectedSource,
          isAppInstalled: _isAppInstalled,
          githubRepositoryUrl: _githubRepositoryUrl,
          variantScrollController: _variantScrollController,
          heroTag: widget.heroTag,
          hasCapability: _hasCapability,
          getVersionForSource: _getVersionForSource,
          isSourceInstalled: _isSourceInstalled,
          onSourceSelected: (String newValue) {
            setState(() {
              _selectedSource = newValue;
              _isAppInstalled = _isSourceInstalled(newValue);
            });
          },
        ),
        const SizedBox(height: 24),
        AppDetailsActions(
          appName: widget.app.name,
          isAppInstalled: _isAppInstalled,
          onLocateApp: _locateApp,
          onHandleAction: _handleAction,
          onLaunchApp: _launchApp,
          onCancelAction: _cancelAction,
        ),
        const SizedBox(height: 24),
        const Divider(),
        AppDetailsSectionTitle(title: AppLocalizations.of(context)!.about),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isLoadingDetails
              ? const ParagraphSkeleton(key: ValueKey('loading'))
              : MarkdownBody(
                  key: const ValueKey('loaded'),
                  data:
                      _extraDetails?['description'] ??
                      (widget.app.description.isEmpty
                          ? AppLocalizations.of(context)!.noResults
                          : widget.app.description),
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(p: theme.textTheme.bodyLarge),
                ),
        ),
        const SizedBox(height: 24),
        if (_hasCapability('has_screenshots') &&
            _extraDetails != null &&
            _extraDetails!['screenshots'] != null &&
            (_extraDetails!['screenshots'] as List).isNotEmpty) ...[
          const SizedBox(height: 24),
          const Divider(),
          AppDetailsSectionTitle(
            title: AppLocalizations.of(context)!.screenshots,
          ),
          AppScreenshots(
            screenshots: _extraDetails!['screenshots'] as List,
            scrollController: _screenshotScrollController,
            onShowScreenshotViewer: _showScreenshotViewer,
          ),
          const SizedBox(height: 24),
        ],
        const SizedBox(height: 24),
        const Divider(),
        AppDetailsSectionTitle(title: AppLocalizations.of(context)!.details),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              AppDetailsInfoRow(
                  icon: Icons.source_rounded,
                  label: AppLocalizations.of(context)!.source,
                  value: widget.app.primarySource,
                ),
                AppDetailsInfoRow(
                  icon: Icons.all_inclusive_rounded,
                  label: AppLocalizations.of(context)!.variant,
                  value: widget.app.sources.join(", "),
                ),
                AppDetailsInfoRow(
                  icon: Icons.verified_rounded,
                  label: AppLocalizations.of(context)!.version,
                  value: widget.app.version,
                ),
                if (_extraDetails?['developer'] != null)
                  AppDetailsInfoRow(
                    icon: Icons.person_rounded,
                    label: AppLocalizations.of(context)!.developer,
                    value: _extraDetails!['developer'],
                  ),
                if (_extraDetails?['license'] != null)
                  AppDetailsInfoRow(
                    icon: Icons.description_rounded,
                    label: AppLocalizations.of(context)!.license,
                    value: _extraDetails!['license'],
                  ),
                AppDependencySection(
                  variant: _getVariantForSource(_selectedSource),
                  hasCapability: _hasCapability,
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAIEnabled = context.select<SettingsController, bool>(
      (s) => s.isAIEnabled,
    );

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            title: AnimatedOpacity(
              opacity: innerBoxIsScrolled ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Text(
                widget.app.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            leading: widget.isEmbedded
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                  ),
            actions: [
              if (widget.app.url != null && widget.app.url!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.language_rounded),
                  tooltip: AppLocalizations.of(context)!.visitWebsite,
                  onPressed: () async {
                    final uri = Uri.parse(widget.app.url!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
              if (isAIEnabled) ...[
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
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: _buildMainContent(
                context,
                colorScheme,
                theme,
                isAIEnabled,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchApp() async {
    final l10n = AppLocalizations.of(context)!;
    final variant = _getVariantForSource(_selectedSource);
    String target = (variant?['id'] != null && _selectedSource == "Flatpak")
        ? variant!['id']!
        : widget.app.name.trim();
    final packageRepo = context.read<PackageRepository>();
    final success = await packageRepo.launchApp(target, _selectedSource);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loadError)),
      );
    }
  }

  Future<void> _locateApp() async {
    final l10n = AppLocalizations.of(context)!;
    final variant = _getVariantForSource(_selectedSource);
    String target = (variant?['id'] != null && _selectedSource == "Flatpak")
        ? variant!['id']!
        : widget.app.name.trim();
    final packageRepo = context.read<PackageRepository>();
    final success = await packageRepo.locateApp(target, _selectedSource);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loadError)),
      );
    }
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

  Future<void> _showAIExplainDialog() async {
    final aiRepo = context.read<AIRepository>();
    final future = aiRepo.aiExplain(
      widget.app.name,
      widget.app.description,
    );
    showDialog(
      context: context,
      builder: (ctx) => AIMarkdownDialog(
        title: AppLocalizations.of(context)!.aiPromptExplain,
        future: future,
      ),
    );
  }

  Future<void> _showAICompareDialog() async {
    final aiRepo = context.read<AIRepository>();
    final future = aiRepo.aiCompareVariants(widget.app.name);
    showDialog(
      context: context,
      builder: (ctx) => AIMarkdownDialog(
        title: AppLocalizations.of(context)!.aiCompareTitle,
        future: future,
        width: 600,
        height: 450,
      ),
    );
  }

  Future<void> _showAICliDialog() async {
    final aiRepo = context.read<AIRepository>();
    final future = aiRepo.aiGenerateCLI(
      widget.app.name,
      _selectedSource,
    );
    showDialog(
      context: context,
      builder: (ctx) => AICliDialog(
        future: future,
      ),
    );
  }

  Future<void> _showAIConflictDialog() async {
    final aiRepo = context.read<AIRepository>();
    final future = aiRepo.aiDetectConflicts(widget.app.name);
    showDialog(
      context: context,
      builder: (ctx) => AIMarkdownDialog(
        title: AppLocalizations.of(context)!.aiConflictTitle,
        future: future,
      ),
    );
  }

  void _showScreenshotViewer(String url) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => ScreenshotViewer(url: url),
    );
  }
}
