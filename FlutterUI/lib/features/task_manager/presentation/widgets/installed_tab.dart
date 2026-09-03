import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/features/task_manager/presentation/widgets/installed_app_list_skeleton.dart';
import 'package:frontend/features/task_manager/presentation/widgets/installed_app_list.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

class InstalledTab extends StatelessWidget {
  final bool isLoading;
  final String selectedSourceFilter;
  final List<AppPackage> filteredApps;
  final ScrollController filterScrollController;
  final ValueChanged<String> onSourceFilterSelected;
  final List<String> availableFilters;

  const InstalledTab({
    super.key,
    required this.isLoading,
    required this.selectedSourceFilter,
    required this.filteredApps,
    required this.filterScrollController,
    required this.onSourceFilterSelected,
    required this.availableFilters,
  });

  @override
  Widget build(BuildContext context) {
    return SmoothSizeSwitcher(
      alignment: Alignment.topCenter,
      child: isLoading
          ? const InstalledAppListSkeleton(key: ValueKey('loading'))
          : Column(
              key: const ValueKey('loaded'),
              children: [
                SizedBox(
                  height: 66,
                  child: Scrollbar(
                    controller: filterScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: filterScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: availableFilters.map((s) {
                          final label = _filterLabel(context, s);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(label),
                              tooltip: AppLocalizations.of(
                                context,
                              )!.sourceFilterSemantics(label),
                              selected: selectedSourceFilter == s,
                              onSelected: (v) {
                                if (v) {
                                  onSourceFilterSelected(s);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                Expanded(child: InstalledAppList(filteredApps: filteredApps)),
              ],
            ),
    );
  }

  String _filterLabel(BuildContext context, String value) {
    final l10n = AppLocalizations.of(context)!;
    switch (value) {
      case 'all':
        return l10n.all;
      case 'managed':
        return l10n.managed;
      case 'unmanaged':
        return l10n.readOnly;
      default:
        return value;
    }
  }
}
