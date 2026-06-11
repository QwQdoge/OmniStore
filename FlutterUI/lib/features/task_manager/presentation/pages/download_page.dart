import "package:frontend/data/repositories/ai_repository.dart";
import "package:frontend/data/repositories/package_repository.dart";
import "package:provider/provider.dart";
import "package:flutter/material.dart";
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/models/task_state.dart';
import 'package:frontend/widgets/smooth_progress_bar.dart';
import 'package:frontend/features/explore/presentation/pages/details_page.dart';
import 'package:frontend/services/update_service.dart';
import 'package:frontend/widgets/magic_pulse_icon.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/core/widgets/skeleton.dart';

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
  bool _isCheckingUpdates = false;
  late String _selectedSourceFilter;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedSourceFilter = "all";
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInstalledApps());

    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
          _applyFilters();
        });
      }
    });
  }

  Future<void> _checkUpdatesWithFeedback() async {
    if (_isCheckingUpdates) return;
    setState(() => _isCheckingUpdates = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final prevCount = UpdateService().availableUpdates.value.length;
      await UpdateService().checkUpdates();
      if (!mounted) return;
      final newCount = UpdateService().availableUpdates.value.length;
      final msg = newCount == 0
          ? l10n.allUpdated
          : l10n.foundUpdates(newCount);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                newCount > 0 ? Icons.system_update_alt : Icons.check_circle_outline,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(msg),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      if (newCount > 0 && prevCount == 0) {
        // 自动跳转到更新标签页
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.checkUpdateFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingUpdates = false);
    }
  }

  Future<void> _loadInstalledApps() async {
    if (!mounted) return;
    setState(() => _isLoadingInstalled = true);
    try {
      final packageRepo = context.read<PackageRepository>();
      final results = await packageRepo.listInstalled();
      if (mounted) {
        setState(() {
          _installedApps = results
              .map((json) => AppPackage.fromJson(json))
              .toList();
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
      final matchesSource =
          _selectedSourceFilter == "all" ||
          app.sources.contains(_selectedSourceFilter) ||
          app.primarySource == _selectedSourceFilter;
      final matchesSearch =
          _searchQuery.isEmpty ||
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

  void _showTerminalDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            children: [
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
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<TaskController>(
                  builder: (context, controller, _) {
                    final logs = controller.logs;
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
    final colorScheme = Theme.of(context).colorScheme;
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                    fillColor: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: AppLocalizations.of(context)!.activity),
                  ListenableBuilder(
                    listenable: UpdateService().availableUpdates,
                    builder: (context, _) {
                      final updates = UpdateService().availableUpdates.value;
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
          Consumer<TaskController>(
            builder: (context, controller, _) {
              if (controller.logs.isNotEmpty) {
                return IconButton(
                  icon: Badge(
                    isLabelVisible: controller.isBusy,
                    child: const Icon(Icons.terminal_outlined),
                  ),
                  onPressed: () => _showTerminalDialog(context),
                  tooltip: AppLocalizations.of(context)!.terminalOutput,
                );
              }
              return const SizedBox.shrink();
            },
          ),
          _isCheckingUpdates
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _loadInstalledApps();
                    _checkUpdatesWithFeedback();
                  },
                  tooltip: AppLocalizations.of(context)!.refresh,
                ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTasksTab(), _buildUpdatesTab(), _buildInstalledTab()],
      ),
    );
  }

  Widget _buildTasksTab() {
    return Consumer<TaskController>(
      builder: (context, taskController, _) {
        if (!taskController.isBusy) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.task_alt,
                  size: 64,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.noActiveTasks,
                  style: const TextStyle(color: Colors.grey),
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
              Text(
                AppLocalizations.of(context)!.currentTask,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      SmoothProgressBar(
                        taskState: TaskState(
                          id: "active",
                          packageName: AppLocalizations.of(context)!.taskProcessing,
                          status: TaskStatus.downloading,
                          progress: taskController.progress ?? 0.0,
                          stage: taskController.status,
                          speed: taskController.speed,
                        ),
                        onCancel: () => taskController.cancelTask(AppLocalizations.of(context)!),
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
    final packageRepo = context.read<PackageRepository>();
    return ListenableBuilder(
      listenable: UpdateService().availableUpdates,
      builder: (context, _) {
        final updates = UpdateService().availableUpdates.value;
        if (updates.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.allUpdated,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.foundUpdates(updates.length),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      for (final update in updates) {
                        UpdateService().startUpdate(
                          update['id'] ?? update['name'],
                          update['source'] == 'Pacman'
                              ? 'Native'
                              : update['source'],
                        );
                      }
                      _tabController.animateTo(0);
                    },
                    icon: const Icon(Icons.system_update_alt, size: 18),
                    label: Text(AppLocalizations.of(context)!.updateAll),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: updates.length,
                itemBuilder: (context, index) {
                  final update = updates[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () async {
                        final results = await packageRepo.searchPackages(
                          update['name'],
                        );
                        if (!context.mounted) return;
                        if (results.isNotEmpty) {
                          final app = results[0];
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AppDetailsPage(app: app),
                            ),
                          );
                        }
                      },
                      title: Text(
                        update['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "${update['current_version']} → ${update['new_version']}",
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Consumer<SettingsController>(
                            builder: (context, settings, _) {
                              if (!settings.isAIEnabled) {
                                return const SizedBox.shrink();
                              }
                              return IconButton(
                                icon: const MagicPulseIcon(
                                  icon: Icons.auto_awesome_rounded,
                                  size: 20,
                                ),
                                tooltip: AppLocalizations.of(
                                  context,
                                )!.aiExplainUpdate,
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
                              UpdateService().startUpdate(
                                update['id'] ?? update['name'],
                                update['source'] == 'Pacman'
                                    ? 'Native'
                                    : update['source'],
                              );
                              _tabController.animateTo(0);
                            },
                            child: Text(AppLocalizations.of(context)!.update),
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
      },
    );
  }

  Future<void> _showAIUpdateSummary(
    String name,
    String current,
    String next,
  ) async {
    final aiRepo = context.read<AIRepository>();
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
            future: aiRepo.aiSummarizeUpdate(name, current, next),
            builder: (context, snapshot) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        height: 200,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Skeleton(width: double.infinity, height: 14),
                            SizedBox(height: 8),
                            Skeleton(width: double.infinity, height: 14),
                            SizedBox(height: 8),
                            Skeleton(width: 200, height: 14),
                          ],
                        ),
                      )
                    : MarkdownBody(
                        key: const ValueKey('loaded'),
                        data: snapshot.data ?? "AI failed to summarize.",
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

  Widget _buildInstalledTab() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isLoadingInstalled
          ? _buildSkeletonList(key: const ValueKey('loading'))
          : Column(
              key: const ValueKey('loaded'),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: ["all", "Native", "Flatpak", "AUR", "AppImage"]
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                s == "all" ? AppLocalizations.of(context)!.explore : s,
                              ),
                              selected: _selectedSourceFilter == s,
                              onSelected: (v) {
                                if (v) {
                                  setState(() {
                                    _selectedSourceFilter = s;
                                    _applyFilters();
                                  });
                                }
                              },
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Expanded(child: _buildInstalledList()),
              ],
            ),
    );
  }

  Widget _buildSkeletonList({Key? key}) {
    return ListView.builder(
      key: key,
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return const Card(
          margin: EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Skeleton(width: 40, height: 40, borderRadius: 8),
            title: Skeleton(width: 120, height: 16),
            subtitle: Skeleton(width: double.infinity, height: 12),
            trailing: Skeleton(width: 60, height: 24, borderRadius: 6),
          ),
        );
      },
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
            Text(
              AppLocalizations.of(context)!.noResults,
              style: const TextStyle(color: Colors.grey),
            ),
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
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: app.icon!,
                      width: 40,
                      height: 40,
                      memCacheWidth: 80,
                      memCacheHeight: 80,
                      placeholder: (context, url) =>
                          const Skeleton(width: 40, height: 40, borderRadius: 0),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.apps),
                    ),
                  )
                : const Icon(Icons.apps, size: 40),
            title: Text(
              app.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Row(
              children: [
                Text(
                  app.primarySource,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    app.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AppDetailsPage(app: app)),
            ),
          ),
        );
      },
    );
  }
}
