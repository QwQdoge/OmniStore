import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';

class SearchFilters extends StatelessWidget {
  final Map<String, bool> sourcesMap;
  final List<String> selectedSources;
  final ValueChanged<List<String>> onSelectedSourcesChanged;
  final ScrollController scrollController;

  const SearchFilters({
    super.key,
    required this.sourcesMap,
    required this.selectedSources,
    required this.onSelectedSourcesChanged,
    required this.scrollController,
  });

  static const Map<String, String> _sourceDisplayNameMap = {
    'pacman': 'Pacman',
    'aur': 'AUR',
    'flatpak': 'Flatpak',
    'appimage': 'AppImage',
    'snap': 'Snap',
    'github': 'GitHub',
    'bitu': 'Bitu',
    'winget': 'Winget',
    'scoop': 'Scoop',
    'brew': 'Homebrew',
  };

  String _displayName(String key) {
    return _sourceDisplayNameMap[key.toLowerCase()] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final enabledSources = sourcesMap.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();

    if (enabledSources.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        child: ListView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(AppLocalizations.of(context)!.all),
                selected: selectedSources.isEmpty,
                onSelected: (selected) {
                  if (selected) {
                    onSelectedSourcesChanged([]);
                  }
                },
              ),
            ),
            ...enabledSources.map((src) {
              final name = _displayName(src);
              final isSelected = selectedSources.contains(name.toLowerCase());
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(name),
                  selected: isSelected,
                  onSelected: (selected) {
                    final newSources = List<String>.from(selectedSources);
                    if (selected) {
                      newSources.add(name.toLowerCase());
                    } else {
                      newSources.remove(name.toLowerCase());
                    }
                    onSelectedSourcesChanged(newSources);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
