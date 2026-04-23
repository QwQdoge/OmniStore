// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import '../services/app_package.dart';
import '../bridges/search_bridge.dart';
import 'app_details_page.dart';
import '../services/history_service.dart';

// 定义显示模式枚举
enum ViewMode { list, grid }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final HistoryService _historyService = HistoryService();

  // 核心状态变量
  List<AppPackage> _results = [];
  bool _isLoading = false;
  bool _hasInput = false; // 实时监测输入框是否有文字
  bool _hasSearched = false;
  ViewMode _viewMode = ViewMode.list; // 默认为列表模式

  // 搜索历史
  List<String> _history = [];

  // 模拟分类数据
  final List<Map<String, dynamic>> _categories = [
    {"name": "开发工具", "icon": Icons.code},
    {"name": "影音娱乐", "icon": Icons.movie},
    {"name": "互联网", "icon": Icons.language},
    {"name": "系统工具", "icon": Icons.settings_suggest},
  ];

  @override
  void initState() {
    super.initState();
    // 关键：监听输入框变化
    _controller.addListener(_handleInputUpdate);
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleInputUpdate);
    _controller.dispose();
    super.dispose();
  }

  // 实时监测输入，决定显示结果页还是分类页
  void _handleInputUpdate() {
    final text = _controller.text.trim();
    if (text.isNotEmpty != _hasInput) {
      setState(() {
        _hasInput = text.isNotEmpty;
        if (!_hasInput) {
          _results = [];
          _hasSearched = false; // ← 重置
        }
      });
    }
  }

  // 清空所有历史记录
  Future<void> _clearAllHistory() async {
    await _historyService.clear();
    setState(() => _history = []);
  }

  // 删除历史记录
  Future<void> _removeHistory(String query) async {
    final updated = await _historyService.remove(query);
    setState(() => _history = updated);
  }

  // 加载历史记录
  Future<void> _loadHistory() async {
    final list = await _historyService.load();
    if (mounted) setState(() => _history = list);
  }

  // 核心搜索逻辑
  Future<void> onSearchIconPressed() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _results = [];
      _isLoading = true;
      _hasSearched = true; // ← 加这一行
    });

    try {
      final service = BackendService();
      final List<dynamic> rawData = await service.searchPackages(query);
      final updatedHistory = await _historyService.add(query);

      setState(() {
        _results = rawData.map((j) => AppPackage.fromJson(j)).toList();
        _isLoading = false;
        _hasSearched = true;
        _history = updatedHistory; // 更新历史记录列表

        // 记录历史
        if (!_history.contains(query)) {
          _history.insert(0, query);
          if (_history.length > 8) _history.removeLast();
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('搜索失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('搜索应用'),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          actions: [
            if (_hasInput)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SegmentedButton<ViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: ViewMode.list,
                      icon: Icon(Icons.view_list_rounded),
                    ),
                    ButtonSegment(
                      value: ViewMode.grid,
                      icon: Icon(Icons.grid_view_rounded),
                    ),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (newSelection) {
                    setState(() => _viewMode = newSelection.first);
                  },
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
          ],
        ),
        SliverToBoxAdapter(child: _buildSearchInput()),
        if (_isLoading)
          const SliverToBoxAdapter(child: LinearProgressIndicator()),
        SliverFillRemaining(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _hasInput
                ? KeyedSubtree(
                    key: const ValueKey('results'),
                    child: _buildResultsArea(),
                  )
                : KeyedSubtree(
                    key: const ValueKey('initial'),
                    child: _buildInitialView(),
                  ),
          ),
        ),
      ],
    );
  }

  // 2. 优化后的搜索框
  Widget _buildSearchInput() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SearchBar(
        controller: _controller,
        hintText: '输入应用名称...',
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(
          Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
        leading: const Icon(Icons.search),
        trailing: [
          if (_hasInput)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => _controller.clear(),
            ),
          IconButton(
            icon: const Icon(Icons.send_rounded),
            onPressed: onSearchIconPressed,
          ),
        ],
        onSubmitted: (_) => onSearchIconPressed(),
      ),
    );
  }

  // 3. 初始视图（分类 + 历史）
  Widget _buildInitialView() {
    return ListView(
      key: const ValueKey("InitialView"),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "搜索历史",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_history.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  // 二次确认，防止误操作
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("清空历史记录"),
                      content: const Text("确定要删除所有搜索历史吗？"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("取消"),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("清空"),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) _clearAllHistory();
                },
                icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                label: const Text("清空"),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ), // 历史记录标签

        if (_history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "暂无搜索历史",
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _history
              .map(
                (h) => InputChip(
                  label: Text(h),
                  onPressed: () {
                    _controller.value = TextEditingValue(
                      text: h,
                      selection: TextSelection.collapsed(offset: h.length),
                    );
                    onSearchIconPressed();
                  },
                  onDeleted: () => _removeHistory(h), // ← 单条删除
                  deleteIcon: const Icon(Icons.close_rounded, size: 14),
                ),
              )
              .toList(),
        ),

        const SizedBox(height: 32),
        const Text(
          "分类浏览",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            return Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: InkWell(
                onTap: () {}, // TODO: 分类点击逻辑
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      cat['icon'],
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(cat['name']),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 4. 结果展示逻辑选择
  Widget _buildResultsArea() {
    if (_isLoading)
      return const SizedBox.shrink(); // loading 交给 LinearProgressIndicator
    if (_hasSearched && _results.isEmpty) {
      return const Center(child: Text("未找到相关应用"));
    }
    if (!_hasSearched) return const Center(child: Text("正在寻找..."));
    return _viewMode == ViewMode.list ? _buildResultList() : _buildResultGrid();
  }

  // --- 列表布局 ---
  Widget _buildResultList() {
    return ListView.builder(
      key: const ValueKey("ListView"),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final app = _results[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            title: Text(
              app.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: app.sources.map((s) => _buildSourceTag(s)).toList(),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showAppDetails(app),
          ),
        );
      },
    );
  }

  // --- 网格/瀑布流布局 ---
  Widget _buildResultGrid() {
    return GridView.builder(
      key: const ValueKey("GridView"),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: 180,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final app = _results[index];
        return Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () => _showAppDetails(app),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(app.name[0].toUpperCase()),
                ),
                const SizedBox(height: 12),
                Text(
                  app.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: app.sources
                      .take(2)
                      .map((s) => _buildSourceTag(s, isSmall: true))
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceTag(String source, {bool isSmall = false}) {
    Color color = Colors.grey;
    if (source == "Pacman") {
      color = Colors.blue;
    } else if (source == "AUR") {
      color = Colors.orange;
    } else if (source == "Flatpak") {
      color = Colors.purple;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 4 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        source,
        style: TextStyle(
          color: color,
          fontSize: isSmall ? 8 : 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showAppDetails(AppPackage app) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AppDetailsPage(app: app)),
    );
  }
}
