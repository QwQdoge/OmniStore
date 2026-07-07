import "package:frontend/data/repositories/package_repository.dart";
import "package:frontend/services/backend_service.dart";
import "package:provider/provider.dart";
import "package:frontend/features/settings/presentation/controllers/settings_controller.dart";
import "package:frontend/features/task_manager/presentation/controllers/task_controller.dart";
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/core/network/github_client.dart';
import 'package:frontend/features/task_manager/presentation/widgets/terminal_dialog.dart';
import 'package:frontend/features/explore/presentation/widgets/action_dialogs.dart';

import 'package:frontend/features/explore/presentation/widgets/app_details_appbar_actions.dart';
import 'package:frontend/features/explore/presentation/widgets/app_main_content.dart';
import 'package:frontend/features/explore/presentation/widgets/screenshot_viewer.dart';

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
  AppPackage? _extraDetails;
  bool _isLoadingDetails = false;

  final ScrollController _screenshotScrollController = ScrollController();
  final ScrollController _variantScrollController = ScrollController();

  bool _hasCapability(String capability) {
    try {
      final sources = BackendService.availableSources.value;
      if (sources.isEmpty) return true;
      final selected = _selectedSource.toLowerCase();
      final cap = sources.firstWhere((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final id = (s['id'] ?? '').toString().toLowerCase();
        return name == selected ||
            id == selected ||
            id.endsWith('.$selected') ||
            id.endsWith(selected);
      }, orElse: () => {});
      if (cap.isEmpty) return true;
      final caps = cap['capabilities'];
      final normalized = capability == 'has_size' ? 'size' : capability;
      if (caps is List) {
        return caps.contains(capability) || caps.contains(normalized);
      }
      if (caps is Map) {
        return caps[capability] ?? caps[normalized] ?? true;
      }
      return true;
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
      if (!mounted) return;
      if (aurConfirmed != true) {
        return;
      }
    }

    final variantMap = _getVariantForSource(_selectedSource);
    String? variantId = variantMap?.id;
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
            content: Text(l10n.success),
          ),
        );
      } else {
        showDialog(context: context, builder: (ctx) => const TerminalDialog());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
              curve: Curves.easeOutCubic,
              child: Text(
                widget.app.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
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
            actions: AppDetailsAppBarActions.buildActions(
              context: context,
              app: widget.app,
              isAIEnabled: isAIEnabled,
              selectedSource: _selectedSource,
              onShowTerminalDialog: _showTerminalDialog,
            ),
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
              child: AppMainContent(
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
                onLocateApp: _locateApp,
                onHandleAction: _handleAction,
                onLaunchApp: _launchApp,
                onCancelAction: _cancelAction,
                isLoadingDetails: _isLoadingDetails,
                screenshotScrollController: _screenshotScrollController,
                onShowScreenshotViewer: _showScreenshotViewer,
                getVariantForSource: _getVariantForSource,
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
    String target = (variant?.id != null && _selectedSource == "Flatpak")
        ? variant!.id!
        : widget.app.name.trim();
    final packageRepo = context.read<PackageRepository>();
    final success = await packageRepo.launchApp(target, _selectedSource);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.loadError)));
    }
  }

  Future<void> _locateApp() async {
    final l10n = AppLocalizations.of(context)!;
    final variant = _getVariantForSource(_selectedSource);
    String target = (variant?.id != null && _selectedSource == "Flatpak")
        ? variant!.id!
        : widget.app.name.trim();
    final packageRepo = context.read<PackageRepository>();
    final success = await packageRepo.locateApp(target, _selectedSource);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.loadError)));
    }
  }

  String? get _githubRepositoryUrl {
    final candidates = <String?>[
      widget.app.url,
      widget.app.homepage,
      _extraDetails?.url,
      _extraDetails?.homepage,
    ];
    for (final candidate in candidates) {
      if (candidate != null && GitHubClient.parseUrl(candidate) != null) {
        return candidate;
      }
    }
    return null;
  }

  AppVariant? _getVariantForSource(String source) {
    if (_extraDetails != null) {
      for (var v in _extraDetails!.variants) {
        if (v.source == source) {
          return v;
        }
      }
    }
    return null;
  }

  String? _getVersionForSource(String source) {
    if (_extraDetails != null) {
      for (var v in _extraDetails!.variants) {
        if (v.source == source) {
          return v.version;
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
    if (_extraDetails != null) {
      for (var v in _extraDetails!.variants) {
        if (v.source == source) {
          return v.installed;
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

  void _showScreenshotViewer(String url) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => ScreenshotViewer(url: url),
    );
  }
}
