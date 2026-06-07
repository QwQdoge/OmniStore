import 'package:flutter/material.dart';

/// Central registry for package source metadata.
/// Used by settings page, search page, and any UI needing source info.
/// All source data is config-driven — no hard imports.
class SourceRegistry {
  const SourceRegistry._();

  /// Display-friendly name for a source key.
  static String displayName(String key) {
    return _metadata[key.toLowerCase()]?.displayName ?? key;
  }

  /// Icon for a source key.
  static IconData icon(String key) {
    return _metadata[key.toLowerCase()]?.icon ?? Icons.extension_rounded;
  }

  /// All known source keys in presentation order.
  static List<String> get allSourceKeys => _metadata.keys.toList();

  /// Sources that are universally available (web-safe, cross-platform).
  static const List<String> universalSources = ['github', 'bitu'];

  /// Sources specific to Linux.
  static const List<String> linuxSources = [
    'pacman',
    'aur',
    'flatpak',
    'appimage',
    'snap',
    'brew',
  ];

  /// Sources specific to Windows.
  static const List<String> windowsSources = ['winget', 'scoop'];

  /// Sources specific to macOS.
  static const List<String> macosSources = ['brew'];

  /// Get the effective source list from a config map.
  /// Falls back to known sources if config is empty.
  static Map<String, bool> effectiveSources(
    Map<String, dynamic> config,
  ) {
    final sourcesMap =
        config['search']?['sources'] as Map<dynamic, dynamic>? ?? {};
    if (sourcesMap.isEmpty) {
      // Return all known sources with sensible defaults
      return {
        for (final key in allSourceKeys) key: universalSources.contains(key),
      };
    }
    return {
      for (final entry in sourcesMap.entries)
        entry.key.toString(): entry.value == true,
    };
  }

  /// Metadata for all known sources.
  static const Map<String, _SourceMeta> _metadata = {
    'github': _SourceMeta('GitHub', Icons.code_rounded),
    'bitu': _SourceMeta('Bitu', Icons.cloud_rounded),
    'pacman': _SourceMeta('Pacman', Icons.terminal_rounded),
    'aur': _SourceMeta('AUR', Icons.build_circle_rounded),
    'flatpak': _SourceMeta('Flatpak', Icons.inventory_2_rounded),
    'appimage': _SourceMeta('AppImage', Icons.apps_rounded),
    'snap': _SourceMeta('Snap', Icons.snap_rounded),
    'winget': _SourceMeta('Winget', Icons.window_rounded),
    'scoop': _SourceMeta('Scoop', Icons.icecream_rounded),
    'brew': _SourceMeta('Homebrew', Icons.local_cafe_rounded),
  };
}

class _SourceMeta {
  const _SourceMeta(this.displayName, this.icon);
  final String displayName;
  final IconData icon;
}
