import 'package:flutter/material.dart'; // 这个文件是搜索页面的 UI 实现，负责展示搜索输入框和结果列表，并调用 SearchService 来获取数据
import '../models/app_package.dart'; // 你的数据模型类，定义了 AppPackage 的结构
// 你的桥接类，负责与 Python 后端通信，获取搜索结果
import '../bridges/search_bridge.dart';
import 'app_details_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<AppPackage> _results = [];
  bool _isLoading = false;

  // --- 补全缺失的搜索核心逻辑 ---
  Future<void> onSearchIconPressed() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      // 这里的逻辑：如果是新搜索，清空旧结果；如果是分页（以后加），则保留。
      // 目前我们直接清空，展示 Loading
      _results = [];
    });

    try {
      // 1. 实例化桥接服务
      final service = BackendService();

      // 2. 调用 Python 后端
      final List<dynamic> rawData = await service.searchPackages(query);

      // 3. 转换模型并更新 UI
      setState(() {
        _results = rawData.map((j) => AppPackage.fromJson(j)).toList();
        _isLoading = false;

        // 4. 自动记录到搜索历史 (可选逻辑)
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

  // 模拟搜索历史数据（以后可以存入 SharedPreferences）
  final List<String> _history = [
    "zen-browser",
    "neovim",
    "visual-studio-code",
    "discord",
  ];

  // 模拟分类数据
  final List<Map<String, dynamic>> _categories = [
    {"name": "开发工具", "icon": Icons.code},
    {"name": "影音娱乐", "icon": Icons.movie},
    {"name": "互联网", "icon": Icons.language},
    {"name": "系统工具", "icon": Icons.settings_suggest},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 标题
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 40, 24, 8),
          child: Text(
            "搜索应用",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),

        // 2. 搜索框
        _buildSearchInput(),

        if (_isLoading) const LinearProgressIndicator(),

        // 3. 根据状态切换内容：搜索中/结果列表 VS 初始页(历史+分类)
        Expanded(
          child: _results.isNotEmpty || _isLoading
              ? _buildResultList()
              : _buildInitialView(),
        ),
      ],
    );
  }

  // --- 初始页面：展示历史记录和分类 ---
  Widget _buildInitialView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 16),
        // 历史记录部分
        const Text(
          "搜索历史",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _history
              .map(
                (h) => ActionChip(
                  label: Text(h),
                  onPressed: () {
                    _controller.text = h;
                    onSearchIconPressed();
                  },
                ),
              )
              .toList(),
        ),

        const SizedBox(height: 32),

        // 分类部分
        const Text(
          "分类浏览",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 桌面端可以设为 2 或 3
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            return InkWell(
              onTap: () {
                // TODO: 跳转分类搜索
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
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

  // --- 搜索框组件 (保持逻辑，优化样式) ---
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
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: onSearchIconPressed,
          ),
        ],
        onSubmitted: (_) => onSearchIconPressed(),
      ),
    );
  }

  Widget _buildResultList() {
    if (!_isLoading && _results.isEmpty) {
      return Center(
        child: Text(_controller.text.isEmpty ? "准备好探索了吗？" : "未找到匹配的应用"),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final app = _results[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade300),
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
                const SizedBox(height: 4),
                Text(
                  app.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // 关键点：展示你 JSON 里的 sources/variants
                Wrap(
                  spacing: 6,
                  children: app.sources.map((s) => _buildSourceTag(s)).toList(),
                ),
              ],
            ),
            trailing: app.installed
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.download_for_offline_outlined),
            onTap: () => _showAppDetails(app),
          ),
        );
      },
    );
  }

  Widget _buildSourceTag(String source) {
    Color color = Colors.grey;
    if (source == "Pacman") color = Colors.blue;
    if (source == "AUR") color = Colors.orange;
    if (source == "Flatpak") color = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
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

  void _showAppDetails(AppPackage app) {
    // 点击详情逻辑
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AppDetailsPage(app: app)),
    );
  }
}
