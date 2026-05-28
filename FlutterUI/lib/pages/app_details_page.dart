import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../services/app_package.dart';
import '../services/backend_service.dart';
import '../services/l10n_service.dart';
import '../services/task_manager.dart';
import '../models/task_state.dart';
import '../widgets/smooth_progress_bar.dart';

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
            content: const Text("发现此应用有 Flatpak 源，通常更稳定。"),
            action: SnackBarAction(
              label: "切换",
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
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12.0),
                    topRight: Radius.circular(12.0),
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
                      title: const Text("同时清理无用依赖 (孤立包)", style: TextStyle(fontSize: 14)),
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
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
          title: const Text("安全风险提示"),
          content: const Text("AUR (Arch User Repository) 是由社区维护的仓库。由于任何人都可以上传包，因此可能存在不安全的代码。在安装之前，建议检查 PKGBUILD。"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("继续安装")),
          ],
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
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    if ((widget.app.url ?? '').isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.language_rounded),
                        tooltip: AppLocalizations.of(context)!.visitWebsite,
                        onPressed: () {
                          // TODO: Implement url_launcher to open widget.app.url
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
                                child: const Icon(Icons.terminal_outlined),
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
                        height: 200,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              (_extraDetails!['screenshots'] as List).length,
                          separatorBuilder: (context, _) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12.0),
                              child: CachedNetworkImage(
                                imageUrl: _extraDetails!['screenshots'][index],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 200,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                      child: CircularProgressIndicator()),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 200,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.broken_image_rounded),
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
                      Icons.source,
                      AppLocalizations.of(context)!.source,
                      widget.app.primarySource,
                    ),
                    _buildInfoRow(
                      Icons.all_inclusive,
                      AppLocalizations.of(context)!.variant,
                      widget.app.sources.join(", "),
                    ),
                    _buildInfoRow(
                      Icons.verified_outlined,
                      AppLocalizations.of(context)!.version,
                      widget.app.version,
                    ),
                    if (_extraDetails?['developer'] != null)
                      _buildInfoRow(
                        Icons.person_outline,
                        AppLocalizations.of(context)!.developer,
                        _extraDetails!['developer'],
                      ),
                    if (_extraDetails?['license'] != null)
                      _buildInfoRow(
                        Icons.description_outlined,
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
            content: Text(L10nService.s('launch_failed', args: [e.toString()])),
          ),
        );
      }
    }
  }

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
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: colorScheme.outlineVariant),
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
              height: 54,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                onPressed: isGlobalBusy ? null : () => _handleAction("-R"),
                child: Text(
                  AppLocalizations.of(context)!.uninstall,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                onPressed: isGlobalBusy ? null : _launchApp,
                icon: const Icon(Icons.rocket_launch_rounded),
                label: Text(
                  AppLocalizations.of(context)!.launch,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      );
    }

        return SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            onPressed: isGlobalBusy ? null : () => _handleAction("-I"),
            icon: const Icon(Icons.download_rounded),
            label: Text(
              AppLocalizations.of(context)!.install,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildHeader(ThemeData theme) {
    final iconUrl = widget.app.icon ?? _extraDetails?['icon'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20.0),
          ),
          alignment: Alignment.center,
          child: iconUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(20.0),
                  child: CachedNetworkImage(
                    imageUrl: iconUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const CircularProgressIndicator(strokeWidth: 2),
                    errorWidget: (context, url, error) => Container(
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "M",
                        style: TextStyle(
                          fontSize: 36,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "M",
                    style: TextStyle(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.app.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (_isAppInstalled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            AppLocalizations.of(context)!.ready,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSource,
                  isDense: true,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  items: <String>{
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

                    return DropdownMenuItem<String>(
                      value: source,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSourceTag(source, isSmall: true),
                          const SizedBox(width: 8),
                          Text(source),
                          if (version != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              "v$version",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.normal,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null && mounted) {
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
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSourceTag(String source, {bool isSmall = false}) {
    return Builder(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      Color color = colorScheme.secondary;
      if (source == "Pacman") {
        color = Colors.blue;
      } else if (source == "AUR") {
        color = Colors.orange;
      } else if (source == "Flatpak") {
        color = Colors.purple;
      } else if (source == "AppImage") {
        color = Colors.teal;
      } else if (source == "Native") {
        color = Colors.blue;
      }

      return Container(
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 4 : 8, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          source,
          style: TextStyle(
              color: color,
              fontSize: isSmall ? 9 : 10,
              fontWeight: FontWeight.bold),
        ),
      );
    });
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
        _buildSectionTitle(theme, "安装信息"),
        if (dlSize != null)
          _buildInfoRow(Icons.downloading_rounded, "下载体积", dlSize.toString()),
        if (insSize != null)
          _buildInfoRow(Icons.storage_rounded, "解压后占用", insSize.toString()),
        if (deps != null && deps.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text("依赖包 (${deps.length})",
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
