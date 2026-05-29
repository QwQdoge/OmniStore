// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../services/app_package.dart';
import '../services/backend_service.dart';
import '../services/category_service.dart';
import '../widgets/magic_pulse_icon.dart';
import '../widgets/ai_app_resolver.dart';
import 'app_details_page.dart';
import '../services/history_service.dart';
import '../services/l10n_service.dart';

enum ViewMode { list, grid }

class SearchPage extends StatefulWidget {
  final bool autoFocus;
  final String? initialQuery;
  const SearchPage({super.key, this.autoFocus = false, this.initialQuery});

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
  String? _aiCorrection;
  ViewMode _viewMode = ViewMode.list;
  List<String> _history = [];
  Timer? _debounce;


  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
    _loadHistory();

    // Listen for global search requests
    BackendService.pendingSearchQuery.addListener(_onGlobalSearchRequested);

    if (widget.initialQuery != null) {
      _controller.text = widget.initialQuery!;
      _search(widget.initialQuery!);
    } else if (BackendService.pendingSearchQuery.value != null) {
      _onGlobalSearchRequested();
    } else {
      _loadInitialContent();
    }
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  void _onGlobalSearchRequested() {
    final query = BackendService.pendingSearchQuery.value;
    if (query != null && mounted) {
      // Clear the pending query immediately to avoid re-triggering
      BackendService.pendingSearchQuery.value = null;

      _controller.text = query;
      _search(query);
    }
  }

  Future<void> _loadInitialContent() async {
    // 自动加载推荐内容，优化“进入搜索页就要加载内容”的体验
    setState(() => _isLoading = true);
    try {
      final resultsMap = await BackendService.instance.getRecommendations();
      if (mounted && _controller.text.isEmpty) {
        setState(() {
          // 在搜索页预加载时，优先展示 "trending" 列表，如果没有则尝试 "featured"
          _results = resultsMap['trending'] ?? resultsMap['featured'] ?? [];
          _isLoading = false;
          _hasSearched = true;
          // 注意：不要设置 _hasInput，让它保持在初始卡片状态但带有结果预加载
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onSearchChanged);
    BackendService.pendingSearchQuery.removeListener(_onGlobalSearchRequested);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final text = _controller.text.trim();
      if (text.length >= 2) {
        _search(text);
      } else {
        setState(() {
          _hasInput = text.isNotEmpty;
          if (!_hasInput) {
            _results = [];
            _hasSearched = false;
            _aiCorrection = null;
          }
        });
      }
    });
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
      _aiCorrection = null;
    });

    try {
      final service = BackendService.instance;
      final List<dynamic> rawData = await service.searchPackages(q);
      final updatedHistory = await _historyService.add(q);

      setState(() {
        _results = rawData.map((j) => AppPackage.fromJson(j)).toList();
        _isLoading = false;
        _history = updatedHistory;
      });

      if (_results.isEmpty) {
        _fetchAICorrection(q);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.failed}: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _fetchAICorrection(String query) async {
    try {
      final corr = await BackendService.instance.aiSuggestCorrection(query);
      if (mounted && corr.isNotEmpty && _results.isEmpty) {
        setState(() {
          _aiCorrection = corr;
        });
      }
    } catch (_) {}
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
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Hero(
          tag: 'search_bar',
          child: SearchBar(
            controller: _controller,
            focusNode: _focusNode,
            autoFocus: false,
            hintText: AppLocalizations.of(context)!.searchHint,
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32.0), // 超大圆角
                side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.2), width: 1.5),
              ),
            ),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24, vertical: 8)),
            leading: Icon(Icons.search_rounded, color: colorScheme.primary, size: 28),
            trailing: [
              if (_hasInput)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: L10nService.s('clear_search'),
                  onPressed: () {
                    _controller.clear();
                    _focusNode.requestFocus();
                  },
                ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: BackendService.isAIEnabled,
                builder: (context, enabled, _) {
                  if (!enabled) return const SizedBox.shrink();
                  return IconButton(
                    icon: const MagicPulseIcon(icon: Icons.auto_awesome_rounded),
                    tooltip: AppLocalizations.of(context)!.aiPromptRecommend,
                    onPressed: _showAIRecommendDialog,
                  );
                },
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _search,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(AppLocalizations.of(context)!.search, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
            onSubmitted: (_) => _search(),
          ),
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
              Material(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(20),
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
                            AppLocalizations.of(context)!.search,
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
                                    title: Text(L10nService.s('clear_history')),
                                    content: Text(L10nService.s('confirm_clear_history')),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)!.cancel)),
                                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(context)!.confirm)),
                                    ],
                                  ),
                                );
                                if (confirm == true) _clearAllHistory();
                              },
                              icon: const Icon(Icons.delete_sweep_rounded, size: 14),
                            label: Text(L10nService.s('clear_history')),
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
                          AppLocalizations.of(context)!.noResults,
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
                            L10nService.s('categories'),
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
                        children: CategoryService.getCategories(context).map((cat) => ActionChip(
                          tooltip: '${AppLocalizations.of(context)!.search} ${cat.name}',
                          avatar: Icon(cat.icon, size: 16, color: cat.color),
                          label: Text(cat.name, style: const TextStyle(fontSize: 12)),
                          onPressed: () => _search('/${cat.id.toLowerCase()}'),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                          backgroundColor: colorScheme.surface,
                        )).toList(),
                      ),
                    ),
                  ],
                ),
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
    final l10n = AppLocalizations.of(context)!;

    if (_hasSearched && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.noResults),
            if (_aiCorrection != null) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MagicPulseIcon(icon: Icons.auto_awesome_rounded, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    l10n.aiCorrection,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      MarkdownBody(
                        data: _aiCorrection!.split('SUGGESTIONS_JSON:')[0], // Hide JSON from text
                        shrinkWrap: true,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(color: Colors.purple, fontSize: 13, height: 1.4),
                        ),
                      ),
                      AIAppResolver(aiText: _aiCorrection!, jsonPrefix: 'SUGGESTIONS_JSON:'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }
    if (!_hasSearched) return Center(child: Text(l10n.searching));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(l10n.resultsFound(_results.length), style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 12),
              SegmentedButton<ViewMode>(
                segments: [
                  ButtonSegment(
                    value: ViewMode.list,
                    icon: const Icon(Icons.view_list_rounded, size: 16),
                    tooltip: L10nService.s('list_view'),
                  ),
                  ButtonSegment(
                    value: ViewMode.grid,
                    icon: const Icon(Icons.grid_view_rounded, size: 16),
                    tooltip: L10nService.s('grid_view'),
                  ),
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

        // 检查是否是完全匹配的大卡片展示
        if (index == 0 && app.isExactMatch) {
          return _buildExactMatchCard(app);
        }
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
                  child: app.icon != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: app.icon!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                color: Colors.purple,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                "M",
                                style: TextStyle(
                                    fontSize: 22,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            "M",
                            style: TextStyle(
                                fontSize: 22,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
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
                            color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.ready,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
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
                        child: Text(AppLocalizations.of(context)!.open, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      )
                    : FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () => _showAppDetails(app),
                        child: Text(AppLocalizations.of(context)!.install, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: app.icon != null
                        ? CachedNetworkImage(
                            imageUrl: app.icon!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            errorWidget: (context, url, error) => Center(
                              child: Text(app.name[0].toUpperCase(),
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold)),
                            ),
                          )
                        : Center(
                            child: Text(app.name[0].toUpperCase(),
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold)),
                          ),
                  ),
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

  Widget _buildExactMatchCard(AppPackage app) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [colorScheme.primaryContainer, colorScheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _showAppDetails(app),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                    ),
                    child: app.icon != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(imageUrl: app.icon!, fit: BoxFit.cover),
                          )
                        : Icon(Icons.apps_rounded, size: 40, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: app.sources.map((s) => _buildSourceTag(s)).toList(),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showAppDetails(app),
                    icon: Icon(app.installed ? Icons.open_in_new_rounded : Icons.download_rounded),
                    label: Text(app.installed ? AppLocalizations.of(context)!.open : AppLocalizations.of(context)!.install),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                app.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              if (app.screenshots != null && app.screenshots!.isNotEmpty) ...[
                const SizedBox(height: 20),
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: app.screenshots!.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: app.screenshots![i],
                        height: 160,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(width: 200, color: colorScheme.surfaceContainer),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAIRecommendDialog() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.purple),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.aiPromptRecommend),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: FutureBuilder<String>(
            future: BackendService.instance.aiRecommend(query),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final text = snapshot.data ?? "AI failed to respond.";
              return SingleChildScrollView(
                child: Column(
                  children: [
                    MarkdownBody(
                      data: text.split('APPS_JSON:')[0],
                      selectable: true,
                    ),
                    AIAppResolver(aiText: text, jsonPrefix: 'APPS_JSON:'),
                  ],
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

  void _showAppDetails(AppPackage app) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AppDetailsPage(app: app),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation.drive(CurveTween(curve: Curves.easeInOutExpo)),
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
    );
  }
}
