class AppPackage {
  final String name;
  final String description;
  final bool installed;
  final String primarySource;
  final String version;
  final List<String> sources; // 这是一个 List，用来存 ["Pacman", "AUR"] 这种
  final String? url;
  final String? id;

  AppPackage({
    required this.name,
    required this.description,
    required this.installed,
    required this.primarySource,
    required this.version,
    required this.sources,
    this.url,
    this.id,
  });

  factory AppPackage.fromJson(Map<String, dynamic> json) {
    // 处理 variants 列表，提取出所有的 source 名称
    var variantsList = json['variants'] as List? ?? [];
    List<String> extractedSources = variantsList
        .map((v) => v['source'].toString())
        .toList();

    return AppPackage(
      name: json['name'] ?? 'Unknown',
      description: json['description'] ?? '',
      // 注意：Python 传过来的是 installed，确保这里对应上
      installed: json['installed'] ?? false,
      primarySource: json['primary_source'] ?? 'Native',
      version: json['version'] ?? 'N/A',
      sources: extractedSources,
      url: json['url'] != null && json['url'].toString().isNotEmpty
          ? json['url'].toString()
          : null,
      id: json['id'] != null && json['id'].toString().isNotEmpty
          ? json['id'].toString()
          : null,
    );
  }
  // 模拟从后台获取推荐数据
  static List<AppPackage> getFeaturedApps() {
    return [
      AppPackage(
        name: 'Zen Browser',
        description: '基于 Firefox 的极简浏览器，专为 Arch Linux 优化。',
        sources: ['AUR', 'Flatpak'],
        installed: false,
        version: '1.2.4',
        primarySource: 'AUR',
      ),
      AppPackage(
        name: 'Neovim',
        description: '高度可扩展的文本编辑器，现代版的 Vim。',
        sources: ['Pacman'],
        installed: true,
        version: '0.10.0',
        primarySource: 'Pacman',
      ),
      AppPackage(
        name: 'Discord',
        description: '深受开发者喜爱的即时通讯与社区平台。',
        sources: ['Flatpak', 'Debian'],
        installed: false,
        version: '0.0.45',
        primarySource: 'Flatpak',
      ),
    ];
  }

  // 模拟获取热门应用数据
  static List<AppPackage> getHotApps() {
    return [
      AppPackage(
        name: 'Visual Studio Code',
        description: '重新定义代码编辑。',
        sources: ['AUR', 'Official'],
        installed: true,
        version: '1.85.0',
        primarySource: 'Official',
      ),
      AppPackage(
        name: 'Spotify',
        description: '数百万首歌曲，随身聆听。',
        sources: ['Flatpak'],
        installed: false,
        version: '1.2.3',
        primarySource: 'Flatpak',
      ),
      AppPackage(
        name: 'Docker Desktop',
        description: '在容器中构建和共享应用。',
        sources: ['AUR'],
        installed: false,
        version: '4.26.0',
        primarySource: 'AUR',
      ),
    ];
  }
}
