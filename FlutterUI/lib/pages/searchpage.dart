// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import '../services/app_package.dart';
import '../services/backend_service.dart';
import 'app_details_page.dart';
import '../services/history_service.dart';

enum ViewMode { list, grid }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final HistoryService _historyService = HistoryService();

  List<AppPackage> _results = [];
  bool _isLoading = false;
  bool _hasInput = false;
  bool _hasSearched = false;
  ViewMode _viewMode = ViewMode.list;
  List<String> _history = [];

  final List<Map<String, dynamic>> _categories = [
    {"name": "开发工具", "icon": Icons.code},
    {"name": "影音娱乐", "icon": Icons.movie},
    {"name": "互联网", "icon": Icons.language},
    {"name": "系统工具", "icon": Icons.settings_suggest},
    {"name": "办公", "icon": Icons.work_outline},
    {"name": "游戏", "icon": Icons.sports_esports_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleInputUpdate);
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleInputUpdate);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleInputUpdate() {
    final text = _controller.text.trim();
    if (text.isNotEmpty != _hasInput) {
      setState(() {
        _hasInput = text.isNotEmpty;
        if (!_hasInput) {
          _results = [];
          _hasSearched = false;
        }
      });
    }
  }

  Future<void> _clearAllHistory() async {
    await _historyService.clear();
    setState(() => _history = []);
  }

  Future<void> _removeHistory(String query) async {
    final updated = await _historyService.remove(query);
    setState(() => _history = updated);
  }

  Future<void> _loadHistory() async {
    final list = await _historyService.load();
    if (mounted) setState(() => _history = list);
  }

  Future<void> _search([String? query]) async {
    final q = (query ?? _controller.text).trim();
    if (q.isEmpty) return;

    if (query != null && query != _controller.text) {
      _controller.text = query;
    }
    _focusNode.unfocus();

    setState(() {
      _results = [];
      _isLoading = true;
      _hasSearched = true;
      _hasInput = true;
    });

    try {
      final service = BackendService();
      final List<dynamic> rawData = await service.searchPackages(q);
      final updatedHistory = await _historyService.add(q);

      setState(() {
        _results = rawData.map((j) => AppPackage.fromJson(j)).toList();
        _isLoading = false;
        _history = updatedHistory;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // ─── 顶部搜索区域（始终居中显示）───
        _buildSearchArea(colorScheme),

        if (_isLoading)
          LinearProgressIndicator(minHeight: 2, color: colorScheme.primary),

        // ─── 内容区 ───
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _hasInput
                ? KeyedSubtree(key: const ValueKey('results'), child: _buildResultsArea())
                : KeyedSubtree(key: const ValueKey('initial'), child: _buildInitialCard(colorScheme)),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // 搜索输入栏
  // ──────────────────────────────────────────────────────────
  Widget _buildSearchArea(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SearchBar(
          controller: _controller,
          focusNode: _focusNode,
          hintText: '搜索应用、游戏、工具...',
          elevation: WidgetStateProperty.all(0),
          backgroundColor: WidgetStateProperty.all(
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
          leading: const Icon(Icons.search),
          trailing: [
            if (_hasInput)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _controller.clear();
                  _focusNode.requestFocus();
                },
              ),
            FilledButton.tonal(
              onPressed: _search,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text("搜索"),
            ),
            const SizedBox(width: 4),
          ],
          onSubmitted: (_) => _search(),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // 初始状态：一个大卡片，内含历史 + 分类
  // ──────────────────────────────────────────────────────────
  Widget _buildInitialCard(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              // ── 搜索历史 + 分类：一个大容器 ──
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 历史标题 ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
                      child: Row(
                        children: [
                          Icon(Icons.history_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(
                            "搜索历史",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          if (_history.isNotEmpty)
                            TextButton.icon(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("清空历史记录"),
                                    content: const Text("确定要删除所有搜索历史吗？"),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消")),
                                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("清空")),
                                    ],
                                  ),
                                );
                                if (confirm == true) _clearAllHistory();
                              },
                              icon: const Icon(Icons.delete_sweep_rounded, size: 14),
                              label: const Text("清空"),
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.error,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ── 历史标签 ──
                    if (_history.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Text(
                          "暂无搜索历史",
                          style: TextStyle(color: colorScheme.outline, fontSize: 13),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _history.map((h) => InputChip(
                            label: Text(h, style: const TextStyle(fontSize: 12)),
                            onPressed: () => _search(h),
                            onDeleted: () => _removeHistory(h),
                            deleteIcon: const Icon(Icons.close_rounded, size: 14),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          )).toList(),
                        ),
                      ),

                    Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),

                    // ── 分类标题 ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Icon(Icons.grid_view_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(
                            "分类浏览",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── 分类网格 ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((cat) => ActionChip(
                          avatar: Icon(cat['icon'] as IconData, size: 16, color: colorScheme.primary),
                          label: Text(cat['name'] as String, style: const TextStyle(fontSize: 12)),
                          onPressed: () => _search(cat['name'] as String),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          backgroundColor: colorScheme.surface,
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // 搜索结果区域
  // ──────────────────────────────────────────────────────────
  Widget _buildResultsArea() {
    if (_isLoading) return const SizedBox.shrink();
    if (_hasSearched && _results.isEmpty) {
      return const Center(child: Text("未找到相关应用"));
    }
    if (!_hasSearched) return const Center(child: Text("正在寻找..."));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text("${_results.length} 个结果", style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 12),
              SegmentedButton<ViewMode>(
                segments: const [
                  ButtonSegment(value: ViewMode.list, icon: Icon(Icons.view_list_rounded, size: 16)),
                  ButtonSegment(value: ViewMode.grid, icon: Icon(Icons.grid_view_rounded, size: 16)),
                ],
                selected: {_viewMode},
                onSelectionChanged: (s) => setState(() => _viewMode = s.first),
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ),
        Expanded(
          child: _viewMode == ViewMode.list ? _buildResultList() : _buildResultGrid(),
        ),
      ],
    );
  }

  Widget _buildResultList() {
    return ListView.builder(
      key: const ValueKey("ListView"),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final app = _results[index];
        final colorScheme = Theme.of(context).colorScheme;
        return InkWell(
          onTap: () => _showAppDetails(app),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    app.name[0].toUpperCase(),
                    style: TextStyle(fontSize: 22, color: colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              app.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: -0.2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (app.installed) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "已就绪",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.primary),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...app.sources.take(2).map((s) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: _buildSourceTag(s, isSmall: true),
                          )),
                          Text(
                            " • ${app.version}",
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                app.installed
                    ? FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () => _showAppDetails(app),
                        child: const Text("打开", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      )
                    : FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () => _showAppDetails(app),
                        child: const Text("安装", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultGrid() {
    return GridView.builder(
      key: const ValueKey("GridView"),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 160,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final app = _results[index];
        return Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () => _showAppDetails(app),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(app.name[0].toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                Text(app.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: app.sources.take(2).map((s) => _buildSourceTag(s, isSmall: true)).toList(),
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
    if (source == "Pacman") color = Colors.blue;
    else if (source == "AUR") color = Colors.orange;
    else if (source == "Flatpak") color = Colors.purple;
    else if (source == "AppImage") color = Colors.teal;
    else if (source == "Native") color = Colors.blue;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 4 : 8, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        source,
        style: TextStyle(color: color, fontSize: isSmall ? 9 : 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showAppDetails(AppPackage app) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AppDetailsPage(app: app)));
  }
}
