import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../services/app_package.dart';
import 'app_details_page.dart';
import '../services/l10n_service.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AppPackage> _installedApps = [];
  bool _isLoadingInstalled = false;
  late String _selectedSourceFilter;
  final BackendService _backend = BackendService();

  @override
  void initState() {
    super.initState();
    _selectedSourceFilter = "all";
    _tabController = TabController(length: 2, vsync: this);
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    setState(() => _isLoadingInstalled = true);
    try {
      final results = await _backend.listInstalled();
      setState(() {
        _installedApps = results.map((json) => AppPackage.fromJson(json)).toList();
      });
    } catch (e) {
      debugPrint("Error loading installed apps: $e");
    } finally {
      setState(() => _isLoadingInstalled = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 来源标签颜色（与 SearchPage 保持一致）
  Color _sourceColor(String source) {
    switch (source) {
      case "Flatpak": return Colors.purple;
      case "AUR": return Colors.orange;
      case "Native":
      case "Pacman": return Colors.blue;
      case "AppImage": return Colors.teal;
      default: return Colors.grey;
    }
  }

  Widget _buildSourceTag(String source) {
    final color = _sourceColor(source);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        source,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
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
        title: Text(L10nService.s('downloads'), style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: L10nService.s('downloads')),
            Tab(text: L10nService.s('ready')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQueueTab(colorScheme),
          _buildInstalledTab(colorScheme),
        ],
      ),
    );
  }

  Widget _buildQueueTab(ColorScheme colorScheme) {
    return ValueListenableBuilder<bool>(
      valueListenable: BackendService.isDownloading,
      builder: (context, isDownloading, child) {
        if (!isDownloading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_done_outlined, size: 64, color: colorScheme.outline),
                const SizedBox(height: 16),
                Text(L10nService.s('no_download_tasks'), style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [_buildActiveTaskCard(colorScheme)],
        );
      },
    );
  }

  Widget _buildActiveTaskCard(ColorScheme colorScheme) {
    return ValueListenableBuilder<AppPackage?>(
      valueListenable: BackendService.activeApp,
      builder: (context, activeApp, _) {
        return Card(
          elevation: 0,
          color: colorScheme.primaryContainer.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.download_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeApp?.name ?? L10nService.s('processing'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                          ValueListenableBuilder<String>(
                            valueListenable: BackendService.globalStatus,
                            builder: (context, status, _) => Text(
                              L10nService.s(status),
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ValueListenableBuilder<double?>(
                      valueListenable: BackendService.globalProgress,
                      builder: (context, progress, _) => Text(
                        progress != null
                            ? L10nService.s('completed_percent', args: [(progress * 100).toInt().toString()])
                            : L10nService.s('waiting'),
                        style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<double?>(
                  valueListenable: BackendService.globalProgress,
                  builder: (context, progress, _) => LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 进入详情按钮
                    if (activeApp != null)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AppDetailsPage(app: activeApp)),
                          );
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(L10nService.s('view_details')),
                      ),
                    TextButton.icon(
                      onPressed: () {
                        BackendService.cancelCurrentTask();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(L10nService.s('task_cancelled_msg'))),
                        );
                      },
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(L10nService.s('cancel_task')),
                      style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstalledTab(ColorScheme colorScheme) {
    if (_isLoadingInstalled) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_installedApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(L10nService.s('no_installed_apps')),
            const SizedBox(height: 8),
            FilledButton.tonal(onPressed: _loadInstalledApps, child: Text(L10nService.s('refresh_list'))),
          ],
        ),
      );
    }

    // 分组
    final Map<String, List<AppPackage>> grouped = {};
    for (final app in _installedApps) {
      grouped.putIfAbsent(app.primarySource, () => []).add(app);
    }
    final sources = ["all", ...grouped.keys.toList()..sort()];

    // 过滤
    final List<AppPackage> filtered = _selectedSourceFilter == "all"
        ? _installedApps
        : (grouped[_selectedSourceFilter] ?? []);

    return Column(
      children: [
        // 来源筛选栏
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sources.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final s = sources[i];
              final isSelected = _selectedSourceFilter == s;
              final color = s == "all" ? colorScheme.primary : _sourceColor(s);
              return FilterChip(
                label: Text(s == "all" ? L10nService.s('all') : s,
                    style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : color, fontWeight: FontWeight.bold)),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedSourceFilter = s),
                selectedColor: color,
                checkmarkColor: Colors.white,
                backgroundColor: color.withValues(alpha: 0.1),
                side: BorderSide(color: color.withValues(alpha: 0.4)),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),

        // 列表
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final app = filtered[index];
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AppDetailsPage(app: app)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        // 图标
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            app.name[0].toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 信息
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(app.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _buildSourceTag(app.primarySource),
                                  const SizedBox(width: 8),
                                  Text(
                                    app.version,
                                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // 操作菜单
                        PopupMenuButton<String>(
                          onSelected: (val) async {
                            if (val == "open") {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => AppDetailsPage(app: app)),
                              );
                            } else if (val == "uninstall") {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(L10nService.s('confirm_uninstall_app', args: [app.name])),
                                  content: Text(L10nService.s('uninstall_app_msg')),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L10nService.s('cancel'))),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(L10nService.s('uninstall')),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => AppDetailsPage(app: app)),
                                );
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                                value: "open",
                                child: ListTile(leading: const Icon(Icons.open_in_new, size: 18), title: Text(L10nService.s('open_details')))),
                            PopupMenuItem(
                                value: "uninstall",
                                child: ListTile(
                                    leading: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    title: Text(L10nService.s('uninstall'), style: const TextStyle(color: Colors.red)))),
                          ],
                          icon: const Icon(Icons.more_vert),
                          tooltip: L10nService.s('more_options'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
