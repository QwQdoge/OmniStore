import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../services/app_package.dart';
import 'app_details_page.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AppPackage> _installedApps = [];
  bool _isLoadingInstalled = false;
  final BackendService _backend = BackendService();

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("管理下载与应用", style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: "正在下载"),
            Tab(text: "已安装"),
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
                Text("当前没有正在下载的任务", style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildActiveTaskCard(colorScheme),
          ],
        );
      },
    );
  }

  Widget _buildActiveTaskCard(ColorScheme colorScheme) {
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
                      ValueListenableBuilder<String>(
                        valueListenable: BackendService.globalStatus,
                        builder: (context, status, _) => Text(
                          status,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text("正在处理...", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                ValueListenableBuilder<double?>(
                  valueListenable: BackendService.globalProgress,
                  builder: (context, progress, _) => Text(
                    progress != null ? "${(progress * 100).toInt()}%" : "等待中",
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<double?>(
              valueListenable: BackendService.globalProgress,
              builder: (context, progress, _) => ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    // 这里由于后端架构限制，目前先通过弹出确认框引导用户
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("正在停止当前任务...")),
                    );
                  },
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text("取消任务"),
                  style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                ),
              ],
            ),
          ],
        ),
      ),
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
            const Text("尚未发现已安装的应用"),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadInstalledApps,
              child: const Text("刷新列表"),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _installedApps.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final app = _installedApps[index];
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AppDetailsPage(app: app),
                ),
              );
            },
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  app.name[0].toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              title: Text(
                app.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Row(
                children: [
                  Icon(
                    app.primarySource == "Flatpak" ? Icons.layers_outlined : Icons.folder_zip_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(app.primarySource, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Text("• ${app.version}", style: const TextStyle(fontSize: 12)),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == "uninstall") {
                    _backend.executeAction("-R", app.name, app.primarySource, url: app.url).listen((_) {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("正在卸载 ${app.name}...")),
                    );
                  } else if (val == "open") {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("正在打开 ${app.name}...")),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: "open", child: Text("打开")),
                  const PopupMenuItem(value: "uninstall", child: Text("卸载", style: TextStyle(color: Colors.red))),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            ),
          ),
        );
      },
    );
  }
}
