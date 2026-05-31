import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../services/backend_service.dart';
import '../services/app_package.dart';
import '../services/task_manager.dart';
import '../models/task_state.dart';
import '../widgets/smooth_progress_bar.dart';
import 'app_details_page.dart';
import '../services/update_service.dart';
import '../widgets/magic_pulse_icon.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AppPackage> _installedApps = [];
  List<AppPackage> _filteredApps = [];
  bool _isLoadingInstalled = false;
  late String _selectedSourceFilter;
  String _searchQuery = "";
  final BackendService _backend = BackendService.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedSourceFilter = "all";
    _tabController = TabController(length: 3, vsync: this);
    _loadInstalledApps();

    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
          _applyFilters();
        });
      }
    });
  }

  Future<void> _loadInstalledApps() async {
    if (!mounted) return;
    setState(() => _isLoadingInstalled = true);
    try {
      final results = await _backend.listInstalled();
      if (mounted) {
        setState(() {
          _installedApps =
              results.map((json) => AppPackage.fromJson(json)).toList();
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint("Error loading installed apps: $e");
    } finally {
      if (mounted) setState(() => _isLoadingInstalled = false);
    }
  }

  void _applyFilters() {
    _filteredApps = _installedApps.where((app) {
      final matchesSource = _selectedSourceFilter == "all" ||
          app.sources.contains(_selectedSourceFilter) ||
          app.primarySource == _selectedSourceFilter;
      final matchesSearch = _searchQuery.isEmpty ||
          app.name.toLowerCase().contains(_searchQuery) ||
          (app.description.toLowerCase().contains(_searchQuery));
      return matchesSource && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _sourceColor(String source) {
    switch (source) {
      case "Flatpak":
        return Colors.purple;
      case "AUR":
        return Colors.orange;
      case "Native":
      case "Pacman":
        return Colors.blue;
      case "AppImage":
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSourceTag(String source) {
    final color = _sourceColor(source);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        source,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showTerminalDialog(BuildContext context) {
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    IconButton(
                      icon: Icon(Icons.close,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.7),
                          size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
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
                                textColor = Colors.redAccent;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.downloads,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchInstalledHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: AppLocalizations.of(context)!.clear,
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = "";
                                _applyFilters();
                              });
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: false,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: [
                  Tab(text: AppLocalizations.of(context)!.activity),
                  ValueListenableBuilder<List<dynamic>>(
                    valueListenable: UpdateService().availableUpdates,
                    builder: (context, updates, _) {
                      return Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(AppLocalizations.of(context)!.updates),
                            if (updates.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.error,
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: Text(
                                  updates.length.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  Tab(text: AppLocalizations.of(context)!.ready),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ValueListenableBuilder<List<String>>(
            valueListenable: BackendService.globalLogs,
            builder: (context, logs, _) {
              if (logs.isNotEmpty) {
                return IconButton(
                  icon: ValueListenableBuilder<bool>(
                    valueListenable: BackendService.isDownloading,
                    builder: (context, isDownloading, _) {
                      return Badge(
                        isLabelVisible: isDownloading,
                        child: const Icon(Icons.terminal_outlined),
                      );
                    },
                  ),
                  onPressed: () => _showTerminalDialog(context),
                  tooltip: AppLocalizations.of(context)!.terminalOutput,
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadInstalledApps();
              UpdateService().checkUpdates();
            },
            tooltip: AppLocalizations.of(context)!.refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksTab(),
          _buildUpdatesTab(),
          _buildInstalledTab(),
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    return StreamBuilder<TaskState?>(
      stream: TaskManager().taskStateStream,
      initialData: TaskManager().currentTask,
      builder: (context, snapshot) {
        final task = snapshot.data;
        if (task == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt,
                    size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.noActiveTasks,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                if (kDebugMode)
                  OutlinedButton(
                    onPressed: () => TaskManager().startMockTask(),
                    child: const Text("Start Mock Task (Debug)"),
                  ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(L10nService.s('current_task'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  if (task.packageName != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        task.packageName!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      if (task.source != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.source_rounded, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                "${AppLocalizations.of(context)!.source}: ${task.source}",
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      SmoothProgressBar(
                        taskState: task,
                        onCancel: () => TaskManager().cancelTask(),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showTerminalDialog(context),
                            icon: const Icon(Icons.terminal, size: 18),
                            label: Text(AppLocalizations.of(context)!.viewLogs),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpdatesTab() {
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: UpdateService().availableUpdates,
      builder: (context, updates, _) {
        if (updates.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.allUpdated,
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: updates.length,
          itemBuilder: (context, index) {
            final update = updates[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(update['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    "${update['current_version']} → ${update['new_version']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: BackendService.isAIEnabled,
                      builder: (context, enabled, _) {
                        if (!enabled) return const SizedBox.shrink();
                        return IconButton(
                          icon: const MagicPulseIcon(icon: Icons.auto_awesome_rounded, size: 20),
                          tooltip: AppLocalizations.of(context)!.aiExplainUpdate,
                          onPressed: () => _showAIUpdateSummary(
                            update['name'],
                            update['current_version'],
                            update['new_version'],
                          ),
                        );
                      },
                    ),
                    ElevatedButton(
                      onPressed: () {
                        UpdateService().startUpdate(update['name'], update['source']);
                        _tabController.animateTo(0);
                      },
                      child: Text(AppLocalizations.of(context)!.update),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAIUpdateSummary(String name, String current, String next) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const MagicPulseIcon(icon: Icons.auto_awesome_rounded),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.aiChangelogTitle),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: FutureBuilder<String>(
            future: BackendService.instance.aiSummarizeUpdate(name, current, next),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
              }
              return MarkdownBody(data: snapshot.data ?? "AI failed to summarize.", selectable: true);
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.confirm)),
        ],
      ),
    );
  }

  Widget _buildInstalledTab() {
    if (_isLoadingInstalled) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: ["all", "Native", "Flatpak", "AUR", "AppImage"].map((s) {
              final isSelected = _selectedSourceFilter == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                      s == "all" ? AppLocalizations.of(context)!.explore : s),
                  selected: isSelected,
                  onSelected: (v) {
                    if (v) {
                      setState(() {
                        _selectedSourceFilter = s;
                        _applyFilters();
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: _buildInstalledList(),
        ),
      ],
    );
  }

  Widget _buildInstalledList() {
    if (_filteredApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.noResults,
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredApps.length,
      itemBuilder: (context, index) {
        final app = _filteredApps[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: app.icon != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: CachedNetworkImage(
                      imageUrl: app.icon!,
                      width: 40,
                      height: 40,
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(strokeWidth: 2),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.apps),
                    ),
                  )
                : const Icon(Icons.apps, size: 40),
            title: Text(app.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                _buildSourceTag(app.primarySource),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(app.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12))),
              ],
            ),
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
          ),
        );
      },
    );
  }
}
