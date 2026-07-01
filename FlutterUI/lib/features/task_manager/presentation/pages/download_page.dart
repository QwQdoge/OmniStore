import "package:frontend/data/repositories/package_repository.dart";
import "package:provider/provider.dart";
import "package:flutter/material.dart";
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/services/update_service.dart';

import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/features/task_manager/presentation/widgets/terminal_dialog.dart';
import 'package:frontend/features/task_manager/presentation/widgets/tasks_tab.dart';
import 'package:frontend/features/task_manager/presentation/widgets/updates_tab.dart';
import 'package:frontend/features/task_manager/presentation/widgets/installed_tab.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _filterScrollController = ScrollController();
  late TabController _tabController;
  List<AppPackage> _installedApps = [];
  List<AppPackage> _filteredApps = [];
  bool _isLoadingInstalled = false;
  bool _isCheckingUpdates = false;
  late String _selectedSourceFilter;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _installedFilterScrollController = ScrollController();

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
      final msg = newCount == 0 ? l10n.allUpdated : l10n.foundUpdates(newCount);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                newCount > 0
                    ? Icons.system_update_alt
                    : Icons.check_circle_outline,
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
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.checkUpdateFailed(e.toString()),
            ),
          ),
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
      if (!mounted) return;
      setState(() {
        _installedApps = results;
        _applyFilters();
      });
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
          (_selectedSourceFilter == "managed" && app.managed) ||
          (_selectedSourceFilter == "unmanaged" && !app.managed) ||
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
    _filterScrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _installedFilterScrollController.dispose();
    super.dispose();
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
                child: SearchBar(
                  controller: _searchController,
                  hintText: AppLocalizations.of(context)!.searchInstalledHint,
                  leading: const Icon(Icons.search_rounded),
                  trailing: [
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: AppLocalizations.of(context)!.clear,
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = "";
                            _applyFilters();
                          });
                        },
                      ),
                  ],
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
          Selector<TaskController, ({bool hasLogs, bool isBusy})>(
            selector: (context, controller) => (
              hasLogs: controller.logs.isNotEmpty,
              isBusy: controller.isBusy,
            ),
            builder: (context, data, _) {
              if (data.hasLogs) {
                return IconButton(
                  icon: Badge(
                    isLabelVisible: data.isBusy,
                    child: const Icon(Icons.terminal_outlined),
                  ),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const TerminalDialog(),
                  ),
                  tooltip: AppLocalizations.of(context)!.terminalOutput,
                );
              }
              return const SizedBox.shrink();
            },
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.fastOutSlowIn,
            child: _isCheckingUpdates
                ? const Padding(
                    key: ValueKey('checking_updates'),
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: Skeleton(width: 20, height: 20, borderRadius: 10),
                    ),
                  )
                : IconButton(
                    key: const ValueKey('refresh_icon'),
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      _loadInstalledApps();
                      _checkUpdatesWithFeedback();
                    },
                    tooltip: AppLocalizations.of(context)!.refresh,
                  ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const TasksTab(),
          UpdatesTab(onUpdateStarted: () => _tabController.animateTo(0)),
          InstalledTab(
            isLoading: _isLoadingInstalled,
            selectedSourceFilter: _selectedSourceFilter,
            filteredApps: _filteredApps,
            filterScrollController: _installedFilterScrollController,
            onSourceFilterSelected: (s) {
              setState(() {
                _selectedSourceFilter = s;
                _applyFilters();
              });
            },
          ),
        ],
      ),
    );
  }
}
