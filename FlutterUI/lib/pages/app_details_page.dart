import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../services/app_package.dart';
import '../services/backend_service.dart';
import '../services/task_manager.dart';
import '../models/task_state.dart';
import '../widgets/magic_pulse_icon.dart';
import '../widgets/smooth_progress_bar.dart';
import '../widgets/app_source_tag.dart';

class AppDetailsPage extends StatefulWidget {
  final AppPackage app;

  const AppDetailsPage({super.key, required this.app});

  @override
  State<AppDetailsPage> createState() => _AppDetailsPageState();
}

class _AppDetailsPageState extends State<AppDetailsPage> {
  late String _selectedSource;
  late bool _isAppInstalled;
  Map<String, dynamic>? _extraDetails;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.app.primarySource;
    _isAppInstalled = widget.app.installed;

    // 即使不是 Flatpak，也尝试获取额外元数据（图标、截图等）
    _fetchExtraDetails().then((_) {
      if (mounted) _checkSourceSuggestion();
    });

  }

  @override
  void dispose() {
    // 不在 dispose 时 kill 进程，因为全局任务应继续运行
    super.dispose();
  }

  void _checkSourceSuggestion() {
    if (_selectedSource != "Flatpak" && widget.app.sources.contains("Flatpak")) {
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted || _isAppInstalled) return;
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
      });
    }
  }

  Future<void> _fetchExtraDetails() async {
    setState(() => _isLoadingDetails = true);
    final target = widget.app.id ?? widget.app.name;
    final details = await BackendService.instance.getAppDetails(target);
    if (mounted) {
      setState(() {
        _extraDetails = details;
        _isLoadingDetails = false;
      });
    }
  }

  void _cancelAction() {
    TaskManager().cancelTask();
    if (mounted) {
      setState(() {});
    }
  }

  void _showTerminalDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
        child: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28.0),
                    topRight: Radius.circular(28.0),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.terminalOutput,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              // AI 分析按钮 (悬浮)
              ValueListenableBuilder<List<String>>(
                valueListenable: BackendService.globalLogs,
                builder: (context, logs, _) {
                  if (!logs.any((l) => l.contains("[ERROR]"))) return const SizedBox.shrink();
                  return ValueListenableBuilder<bool>(
                    valueListenable: BackendService.isAIEnabled,
                    builder: (context, enabled, _) {
                      if (!enabled) return const SizedBox.shrink();
                      return Container(
                        width: double.infinity,
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary, size: 18),
                            const SizedBox(width: 12),
                            Text(AppLocalizations.of(context)!.aiAnalysisPrompt,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            TextButton(
                              onPressed: () =>
                                  _showAIErrorAnalysis(logs.join("\n")),
                              child: Text(AppLocalizations.of(context)!.analyzeNow,
                                  style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              // 日志内容
              Expanded(
                child: ValueListenableBuilder<List<String>>(
                  valueListenable: BackendService.globalLogs,
                  builder: (context, logs, _) {
                    return logs.isEmpty
                        ? Center(
                            child: Text(
                              AppLocalizations.of(context)!.waitingForOutput,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontFamily: 'monospace',
                              ),
                            ),
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.all(12),
                            itemCount: logs.length,
                            itemBuilder: (context, i) {
                              final log = logs[logs.length - 1 - i];
                              Color textColor = theme.colorScheme.onSurface;
                              if (log.contains("[ERROR]")) {
                                textColor = theme.colorScheme.error;
                              }
                              if (log.contains("[INFO]")) {
                                textColor = Colors.greenAccent.shade400;
                              }
                              return Text(
                                log,
                                style: TextStyle(
                                  color: textColor,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              );
                            },
                          );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(String flag) async {
    if (TaskManager().isBusy) return;

    final isUninstall = flag == "-R";
    bool cleanOrphans = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isUninstall
                    ? AppLocalizations.of(context)!.confirmUninstall
                    : AppLocalizations.of(context)!.confirmInstall,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.confirmActionMsg(widget.app.name),
                  ),
                  if (isUninstall && _selectedSource == "Native") ...[
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: cleanOrphans,
                      onChanged: (val) {
                        setDialogState(() => cleanOrphans = val ?? false);
                      },
                      title: Text(AppLocalizations.of(context)!.cleanOrphans,
                          style: const TextStyle(fontSize: 14)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                FilledButton(
                  style: isUninstall
                      ? FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        )
                      : null,
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(AppLocalizations.of(context)!.confirm),
                ),
              ],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            );
          }
        );
      },
    );

    if (confirmed != true) return;

    // Security Warning for AUR
    if (_selectedSource == "AUR" && mounted) {
      final aurConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 48),
          title: Text(AppLocalizations.of(context)!.securityWarning),
          content: Text(AppLocalizations.of(context)!.aurSecurityDesc),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context)!.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppLocalizations.of(context)!.continueInstall)),
          ],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      );
      if (aurConfirmed != true) return;
    }

    final success = await TaskManager().startTask(
      id: "task-${widget.app.name}",
      packageName: widget.app.name.trim(),
      source: _selectedSource,
      actionFlag: isUninstall && cleanOrphans ? "-Rsn" : flag, // Use -Rsn for clean uninstall
      url: widget.app.url,
    );

    if (success && mounted) {
      if (flag == "-I") {
        setState(() => _isAppInstalled = true);
      } else if (flag == "-R") {
        setState(() => _isAppInstalled = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  pinned: true,
                  title: Text(widget.app.name, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
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
                  ValueListenableBuilder<bool>(
                    valueListenable: BackendService.isAIEnabled,
                    builder: (context, enabled, _) {
                      if (!enabled) return const SizedBox.shrink();
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Badge(
                                child: Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary)),
                            tooltip: AppLocalizations.of(context)!.aiPromptExplain,
                            onPressed: _showAIExplainDialog,
                          ),
                          if (widget.app.variants.length > 1)
                            IconButton(
                              icon: Icon(Icons.compare_arrows_rounded, color: theme.colorScheme.primary),
                              tooltip: AppLocalizations.of(context)!.aiCompareTitle,
                              onPressed: _showAICompareDialog,
                            ),
                          IconButton(
                            icon: Icon(Icons.terminal_rounded, color: theme.colorScheme.primary),
                            tooltip: AppLocalizations.of(context)!.aiCliTitle,
                            onPressed: _showAICliDialog,
                          ),
                          IconButton(
                            icon: Icon(Icons.report_problem_rounded, color: theme.colorScheme.primary),
                            tooltip: AppLocalizations.of(context)!.aiConflictTitle,
                            onPressed: _showAIConflictDialog,
                          ),
                        ],
                      );
                    },
                  ),
                    StreamBuilder<TaskState?>(
                      stream: TaskManager().taskStateStream,
                      initialData: TaskManager().currentTask,
                      builder: (context, snapshot) {
                        final isBusy = TaskManager().isBusy;
                        return ValueListenableBuilder<List<String>>(
                          valueListenable: BackendService.globalLogs,
                          builder: (context, logs, _) {
                            if (!isBusy && logs.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return IconButton(
                              icon: Badge(
                                isLabelVisible: isBusy,
                                child: const Icon(Icons.terminal_rounded),
                              ),
                              tooltip:
                                  AppLocalizations.of(context)!.terminalOutput,
                              onPressed: _showTerminalDialog,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
              body: SelectionArea(
                child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(theme),
                    const SizedBox(height: 24),
                    _buildActionArea(colorScheme),
                    const SizedBox(height: 32),
                    const Divider(),
                    _buildSectionTitle(
                        theme, AppLocalizations.of(context)!.about),
                    if (_isLoadingDetails)
                      const Center(child: CircularProgressIndicator())
                    else
                      MarkdownBody(
                        data: _extraDetails?['description'] ??
                            (widget.app.description.isEmpty
                                ? AppLocalizations.of(context)!.noResults
                                : widget.app.description),
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: theme.textTheme.bodyLarge,
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (_extraDetails != null &&
                        _extraDetails!['screenshots'] != null &&
                        (_extraDetails!['screenshots'] as List).isNotEmpty) ...[
                      _buildSectionTitle(
                          theme, AppLocalizations.of(context)!.screenshots),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: ListView.separated(
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
                                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => _showScreenshotViewer(imageUrl),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    width: 360,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 360,
                                      color: colorScheme.surfaceContainerHighest,
                                      child: const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      width: 360,
                                      color: colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.broken_image_rounded),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    _buildSectionTitle(
                        theme, AppLocalizations.of(context)!.details),
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
            ),
          ),
    );
  }

  Future<void> _launchApp() async {
    // 找到对应的 variant
    final variant = _getVariantForSource(_selectedSource);
    String target = (variant?['id'] != null && _selectedSource == "Flatpak")
        ? variant!['id']!
        : widget.app.name.trim();

    try {
      await Process.start(BackendService.venvPython, [
        BackendService.scriptPath,
        '--launch',
        target,
        '--source',
        _selectedSource,
      ], workingDirectory: BackendService.workingDir);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${AppLocalizations.of(context)!.failed}: $e"),
          ),
        );
      }
    }
  }

  // (Section 10: App Details Action Buttons)
  Widget _buildActionArea(ColorScheme colorScheme) {
    return StreamBuilder<TaskState?>(
      stream: TaskManager().taskStateStream,
      initialData: TaskManager().currentTask,
      builder: (context, snapshot) {
        final task = snapshot.data;
        if (task != null && task.id == "task-${widget.app.name}") {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: SmoothProgressBar(
              taskState: task,
              onCancel: _cancelAction,
            ),
          );
        }

        final isGlobalBusy = TaskManager().isBusy;

        if (_isAppInstalled) {
          return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28.0),
                  ),
                ),
                onPressed: isGlobalBusy ? null : () => _handleAction("-R"),
                child: Text(
                  AppLocalizations.of(context)!.uninstall,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28.0),
                  ),
                ),
                onPressed: isGlobalBusy ? null : _launchApp,
                icon: const Icon(Icons.rocket_launch_rounded),
                label: Text(
                  AppLocalizations.of(context)!.launch,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      );
    }

        return SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28.0),
              ),
            ),
            onPressed: isGlobalBusy ? null : () => _handleAction("-I"),
            icon: const Icon(Icons.download_rounded),
            label: Text(
              AppLocalizations.of(context)!.install,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic>? _getVariantForSource(String source) {
    if (_extraDetails != null && _extraDetails!['variants'] != null) {
      for (var v in _extraDetails!['variants']) {
        if (v['source'] == source) return v;
      }
    }
    // Fallback to widget.app.variants if we have them
    // But currently AppPackage only has names. We might need to store full variant objects in AppPackage
    return null;
  }

  // (Section 8: App Details Header)
  Widget _buildHeader(ThemeData theme) {
    final iconUrl = widget.app.icon ?? _extraDetails?['icon'];
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Hero(
          tag: 'app-icon-shelf-${widget.app.name}-${widget.app.primarySource}',
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: iconUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(24.0),
                    child: CachedNetworkImage(
                      imageUrl: iconUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(strokeWidth: 2),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(24.0),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.app.name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 48,
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.app.name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 48,
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w900,
                      ),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isAppInstalled) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppLocalizations.of(context)!.ready,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      AppSourceTag(
                        source: _selectedSource,
                        mode: AppSourceTagMode.trust,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: <String>{
                    for (var v in widget.app.variants) v.source,
                    if (_extraDetails != null &&
                        _extraDetails!['variants'] != null)
                      for (var v in _extraDetails!['variants'])
                        v['source'].toString(),
                    _selectedSource,
                  }.map((String source) {
                    // Try to find version for this source
                    String? version;
                    if (_extraDetails != null &&
                        _extraDetails!['variants'] != null) {
                      for (var v in _extraDetails!['variants']) {
                        if (v['source'] == source) {
                          version = v['version'] ?? v['last_version'];
                          break;
                        }
                      }
                    }
                    if (version == null) {
                      for (var v in widget.app.variants) {
                        if (v.source == source) {
                          version = v.version;
                          break;
                        }
                      }
                    }

                    return ButtonSegment<String>(
                      value: source,
                      label: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(source, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            if (version != null)
                              Text(
                                "v$version",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
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
                    if (mounted) {
                      setState(() {
                        _selectedSource = newValue;
                        // 更新安装状态（基于当前选择的来源）
                        bool isInstalled = false;
                        if (_extraDetails != null &&
                            _extraDetails!['variants'] != null) {
                          for (var v in _extraDetails!['variants']) {
                            if (v['source'] == newValue) {
                              isInstalled = v['installed'] ?? false;
                              break;
                            }
                          }
                        } else {
                          for (var v in widget.app.variants) {
                            if (v.source == newValue) {
                              isInstalled = v.installed;
                              break;
                            }
                          }
                        }
                        _isAppInstalled = isInstalled;
                      });
                    }
                  },
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // (Section 9: App Details Typography & Content)
  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: theme.colorScheme.primary,
          letterSpacing: -1.0,
        ),
      ),
    );
  }


  Widget _buildDependencySection(ThemeData theme) {
    final variant = _getVariantForSource(_selectedSource);
    if (variant == null) return const SizedBox.shrink();

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
        if (dlSize != null)
          _buildInfoRow(Icons.downloading_rounded,
              AppLocalizations.of(context)!.downloadSize, dlSize.toString()),
        if (insSize != null)
          _buildInfoRow(Icons.storage_rounded,
              AppLocalizations.of(context)!.installedSize, insSize.toString()),
        if (deps != null && deps.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context)!.dependenciesCount(deps.length),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: deps.map((d) => Chip(
              label: Text(d.toString(), style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )).toList(),
          ),
        ],
      ],
    );
  }

  Future<void> _showAIExplainDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const MagicPulseIcon(icon: Icons.auto_awesome_rounded),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.aiPromptExplain),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400, // Fixed height to prevent overflow in dialog
          child: FutureBuilder<String>(
            future: BackendService.instance.aiExplain(
              widget.app.name,
              widget.app.description,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return SingleChildScrollView(
                child: MarkdownBody(
                  data: snapshot.data ?? AppLocalizations.of(context)!.aiResponseFailed,
                  selectable: true,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _showAIErrorAnalysis(String logs) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const MagicPulseIcon(icon: Icons.auto_awesome_rounded),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.aiPromptError),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 450, // Fixed height
          child: FutureBuilder<String>(
            future: BackendService.instance.aiAnalyzeError(logs),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return SingleChildScrollView(
                child: MarkdownBody(
                  data: snapshot.data ?? AppLocalizations.of(context)!.aiResponseFailed,
                  selectable: true,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _showAICompareDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const MagicPulseIcon(icon: Icons.auto_awesome_rounded),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.aiCompareTitle),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 450, // Fixed height
          child: FutureBuilder<String>(
            future: BackendService.instance.aiCompareVariants(widget.app.name),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return SingleChildScrollView(
                child: MarkdownBody(
                  data: snapshot.data ?? AppLocalizations.of(context)!.aiResponseFailed,
                  selectable: true,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _showAICliDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const MagicPulseIcon(icon: Icons.auto_awesome_rounded),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.aiCliTitle),
          ],
        ),
        content: FutureBuilder<String>(
          future: BackendService.instance.aiGenerateCLI(widget.app.name, _selectedSource),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            }
            final cmd = snapshot.data ?? "";
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(cmd, style: const TextStyle(fontFamily: 'monospace')),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: cmd));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.aiCommandCopied)),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(AppLocalizations.of(context)!.aiCopyCommand),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.confirm)),
        ],
      ),
    );
  }

  Future<void> _showAIConflictDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const MagicPulseIcon(icon: Icons.auto_awesome_rounded),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.aiConflictTitle),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400, // Fixed height
          child: FutureBuilder<String>(
            future: BackendService.instance.aiDetectConflicts(widget.app.name),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
              }
              return SingleChildScrollView(
                child: MarkdownBody(data: snapshot.data ?? AppLocalizations.of(context)!.aiAnalysisFailed, selectable: true),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.confirm)),
        ],
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
    if (iconData == null) return null;
    return Icon(iconData, size: 16);
  }

  void _showScreenshotViewer(String url) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        body: Stack(
          children: [
            Center(
              child: Hero(
                tag: 'screenshot-$url',
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
