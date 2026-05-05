import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../services/backend_service.dart';
import '../services/app_package.dart';
import 'app_details_page.dart';
import '../services/l10n_service.dart';
import '../services/update_service.dart';

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
  final BackendService _backend = BackendService();
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
                    hintText: L10nService.s('search_installed_hint'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
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
                  Tab(text: AppLocalizations.of(context)!.searching),
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
            tooltip: L10nService.s('refresh'),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: BackendService.isDownloading,
      builder: (context, isDownloading, _) {
        return ValueListenableBuilder<AppPackage?>(
          valueListenable: BackendService.activeApp,
          builder: (context, activeApp, _) {
            if (activeApp == null && !isDownloading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.task_alt,
                        size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(L10nService.s('no_active_tasks'),
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            final displayApp = activeApp ?? AppPackage(name: "Processing...", description: "", installed: false, version: "", variants: [], primarySource: "");

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L10nService.s('current_task'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                                isDownloading ? Icons.downloading : Icons.task_alt,
                                size: 40,
                                color: isDownloading ? Colors.blue : Colors.green),
                            title: Text(displayApp.name,
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: ValueListenableBuilder<String>(
                              valueListenable: BackendService.globalStatus,
                              builder: (context, status, _) => Text(L10nService.s(status)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ValueListenableBuilder<double?>(
                            valueListenable: BackendService.globalProgress,
                            builder: (context, progress, _) {
                              return Column(
                                children: [
                                  LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  const SizedBox(height: 8),
                                  if (progress != null)
                                    Text("${(progress * 100).toInt()}%",
                                        style: const TextStyle(fontSize: 12)),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isDownloading)
                                TextButton(
                                  onPressed: () => BackendService.cancelCurrentTask(),
                                  child: Text(L10nService.s('cancel'),
                                      style: const TextStyle(color: Colors.red)),
                                ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _showTerminalDialog(context),
                                child: Text(L10nService.s('view_logs')),
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
                Text(L10nService.s('all_updated'),
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
                trailing: ElevatedButton(
                  onPressed: () {
                    // Start update
                    UpdateService()
                        .startUpdate(update['name'], update['source']);
                    _tabController.animateTo(0);
                  },
                  child: Text(L10nService.s('update')),
                ),
              ),
            );
          },
        );
      },
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
            Text(L10nService.s('no_results'),
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
