class AppVariant {
  final String source;
  final String version;
  final bool installed;
  final String description;
  final String? url;
  final String? id;

  AppVariant({
    required this.source,
    required this.version,
    required this.installed,
    required this.description,
    this.url,
    this.id,
  });

  factory AppVariant.fromJson(Map<String, dynamic> json) {
    return AppVariant(
      source: json['source'] ?? 'Unknown',
      version: json['version'] ?? json['last_version'] ?? 'N/A',
      installed: json['installed'] ?? false,
      description: json['description'] ?? '',
      url: json['url'],
      id: json['id'],
    );
  }
}

class AppPackage {
  final String name;
  final String description;
  final bool installed;
  final String primarySource;
  final String version;
  final List<AppVariant> variants;
  final String? url;
  final String? id;

  final String? icon;
  final List<String>? screenshots;
  final String? developer;
  final String? homepage;
  final bool isExactMatch;

  AppPackage({
    required this.name,
    required this.description,
    required this.installed,
    required this.primarySource,
    required this.version,
    required this.variants,
    this.url,
    this.id,
    this.icon,
    this.screenshots,
    this.developer,
    this.homepage,
    this.isExactMatch = false,
  });

  List<String> get sources => variants.map((v) => v.source).toList();

  factory AppPackage.fromJson(Map<String, dynamic> json) {
    var variantsData = json['variants'] is List ? json['variants'] as List : [];
    List<AppVariant> parsedVariants = variantsData
        .whereType<Map<String, dynamic>>()
        .map((v) => AppVariant.fromJson(v))
        .toList();

    String primarySource = (json['primary_source'] ?? json['source'] ?? 'Native').toString();

    // 如果没有 variants，根据当前信息构造一个
    if (parsedVariants.isEmpty) {
      parsedVariants.add(AppVariant(
        source: primarySource,
        version: (json['version'] ?? json['last_version'] ?? 'N/A').toString(),
        installed: json['installed'] == true,
        description: (json['description'] ?? '').toString(),
        url: json['url']?.toString(),
        id: json['id']?.toString(),
      ));
    }

    return AppPackage(
      name: (json['name'] ?? 'Unknown').toString(),
      description: (json['description'] ?? '').toString(),
      installed: json['installed'] == true,
      primarySource: primarySource,
      version: (json['version'] ?? json['last_version'] ?? 'N/A').toString(),
      variants: parsedVariants,
      url: json['url'] != null && json['url'].toString().isNotEmpty
          ? json['url'].toString()
          : null,
      id: json['id'] != null && json['id'].toString().isNotEmpty
          ? json['id'].toString()
          : null,
      icon: json['icon']?.toString(),
      screenshots: json['screenshots'] is List
          ? (json['screenshots'] as List).map((e) => e.toString()).toList()
          : null,
      developer: json['developer']?.toString(),
      homepage: json['homepage']?.toString(),
      isExactMatch: json['is_exact_match'] == true,
    );
  }

  // 模拟数据保留以供参考或测试，但通常我们会通过 BackendService 获取
  static List<AppPackage> getFeaturedApps() {
    return [
      AppPackage(
        name: 'Zen Browser',
        description: '基于 Firefox 的极简浏览器，专为 Arch Linux 优化。',
        variants: [
          AppVariant(source: 'AUR', version: '1.2.4', installed: false, description: ''),
          AppVariant(source: 'Flatpak', version: '1.2.4', installed: false, description: ''),
        ],
        installed: false,
        version: '1.2.4',
        primarySource: 'AUR',
      ),
      AppPackage(
        name: 'Neovim',
        description: '高度可扩展的文本编辑器，现代版的 Vim。',
        variants: [
          AppVariant(source: 'Pacman', version: '0.10.0', installed: true, description: ''),
        ],
        installed: true,
        version: '0.10.0',
        primarySource: 'Pacman',
      ),
    ];
  }
}
