class AppPackage {
  final String name;
  final String description;
  final bool installed;
  final String primarySource;
  final String version;
  final List<String> sources; // 这是一个 List，用来存 ["Pacman", "AUR"] 这种

  AppPackage({
    required this.name,
    required this.description,
    required this.installed,
    required this.primarySource,
    required this.version,
    required this.sources,
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
    );
  }
}
