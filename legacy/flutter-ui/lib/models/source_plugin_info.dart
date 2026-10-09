class SourcePluginInfo {
  final String id;
  final String name;
  final String version;
  final bool enabled;
  final bool available;
  final bool builtin;
  final bool legacy;
  final List<String> platforms;
  final List<String> capabilities;
  final List<String> permissions;
  final String? error;

  const SourcePluginInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.enabled,
    required this.available,
    required this.builtin,
    required this.legacy,
    required this.platforms,
    required this.capabilities,
    required this.permissions,
    this.error,
  });

  factory SourcePluginInfo.fromJson(Map<String, dynamic> json) {
    return SourcePluginInfo(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['id'] ?? '').toString(),
      version: (json['version'] ?? '').toString(),
      enabled: json['enabled'] == true,
      available: json['available'] != false,
      builtin: json['builtin'] == true,
      legacy: json['legacy'] == true,
      platforms: json['platforms'] is List
          ? (json['platforms'] as List).map((e) => e.toString()).toList()
          : const [],
      capabilities: json['capabilities'] is List
          ? (json['capabilities'] as List).map((e) => e.toString()).toList()
          : const [],
      permissions: json['permissions'] is List
          ? (json['permissions'] as List).map((e) => e.toString()).toList()
          : const [],
      error: json['error']?.toString(),
    );
  }
}
