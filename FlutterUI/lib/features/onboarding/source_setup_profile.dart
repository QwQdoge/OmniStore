/// Validated environment recommendations for first-run source selection.
class SourceSetupProfile {
  const SourceSetupProfile({
    this.platform = '',
    this.nativeManager = '',
    this.sources = const [],
  });

  final String platform;
  final String nativeManager;
  final List<String> sources;
  bool get detected => const ['linux', 'windows', 'macos'].contains(platform);
  bool get supportsAur => platform == 'linux' && nativeManager == 'pacman';

  static const nativeSources = {
    'pacman',
    'apt',
    'dnf',
    'zypper',
    'apk',
    'winget',
    'brew',
  };
  static const platformSources = {
    ...nativeSources,
    'aur',
    'flatpak',
    'appimage',
    'scoop',
    'chocolatey',
  };

  factory SourceSetupProfile.fromEnvironment(Map<String, dynamic> environment) {
    final system = environment['system'];
    if (system is! Map) return const SourceSetupProfile();
    final platform = system['platform'];
    if (platform is! String ||
        !const ['linux', 'windows', 'macos'].contains(platform)) {
      return const SourceSetupProfile();
    }
    final compatible = switch (platform) {
      'linux' => {'pacman', 'apt', 'dnf', 'zypper', 'apk'},
      'windows' => {'winget'},
      _ => {'brew'},
    };
    final candidate = system['native_manager'];
    final manager =
        candidate is String &&
            compatible.contains(candidate) &&
            system['immutable'] != true
        ? candidate
        : '';
    final allowed = switch (platform) {
      'linux' => {
        'flatpak',
        'appimage',
        if (manager.isNotEmpty) manager,
        if (manager == 'pacman') 'aur',
      },
      _ => {if (manager.isNotEmpty) manager},
    };
    final raw = system['recommended_sources'];
    final sources = raw is List
        ? raw.whereType<String>().where(allowed.contains).toSet().toList()
        : <String>[];
    return SourceSetupProfile(
      platform: platform,
      nativeManager: manager,
      sources: List.unmodifiable(sources),
    );
  }

  void apply(
    Map<String, dynamic> sourcesConfig,
    Map<String, dynamic> plugins, {
    required bool enableAur,
  }) {
    if (!detected) return;
    for (final source in platformSources) {
      final compatible = switch (platform) {
        'linux' =>
          source == nativeManager ||
              const {'flatpak', 'appimage'}.contains(source),
        'windows' => const {'winget', 'scoop', 'chocolatey'}.contains(source),
        _ => source == 'brew',
      };
      final enabled = source == 'aur'
          ? supportsAur && enableAur
          : compatible &&
                (sources.contains(source) || sourcesConfig[source] == true);
      sourcesConfig[source] = enabled;
      plugins['builtin.$source'] = enabled;
    }
  }
}
