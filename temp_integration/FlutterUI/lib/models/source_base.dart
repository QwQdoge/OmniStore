
/// Unified interface for all software sources on Android and Desktop frontend logic.
abstract class UnifiedSource {
  final String name;
  bool enabled;
  double weight;

  UnifiedSource({required this.name, this.enabled = true, this.weight = 1.0});

  /// Search for packages in this source.
  Future<List<Map<String, dynamic>>> search(
    String query, {
    int page = 1,
    Map<String, dynamic>? filters,
  });

  /// Install a package.
  Future<bool> install(
    Map<String, dynamic> package, {
    Function(String)? onProgress,
  });

  /// Uninstall a package.
  Future<bool> uninstall(
    Map<String, dynamic> package, {
    Function(String)? onProgress,
  });

  /// Launch the application.
  Future<bool> launch(Map<String, dynamic> package);

  /// Locate the installation directory or app info.
  Future<bool> locate(Map<String, dynamic> package);

  /// Fetch detailed information about a package.
  Future<Map<String, dynamic>> getDetails(String packageId);

  /// Check for updates for a specific package.
  Future<Map<String, dynamic>?> checkUpdate(String packageId);

  Map<String, dynamic> toMap() {
    return {'name': name, 'enabled': enabled, 'weight': weight};
  }
}
