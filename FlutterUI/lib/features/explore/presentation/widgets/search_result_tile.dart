import 'package:flutter/material.dart';
import 'package:frontend/features/explore/presentation/controllers/browse_controller.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/core/widgets/app_source_tag.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

class SearchResultTile extends StatelessWidget {
  final AppPackage app;
  final bool isDesktop;
  final VoidCallback onTap;

  const SearchResultTile({
    super.key,
    required this.app,
    required this.isDesktop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final heroTag = 'search-result-${app.name}-${app.primarySource}';

    // Check if this specific app is currently selected in BrowseController
    final isSelected = context.select<BrowseController, bool>((b) {
      final selected = b.selectedApp;
      if (selected == null) return false;
      if (selected.id != null && app.id != null) {
        return selected.id == app.id;
      }
      return selected.name == app.name;
    });

    // Select ONLY the boolean value of whether THIS SPECIFIC APP is the current task
    final isCurrentTask = context.select<TaskController, bool>((
      taskController,
    ) {
      return taskController.isBusy &&
          (taskController.packageName == app.name ||
              taskController.packageName == app.id);
    });

    return Semantics(
      label: 'Search result: ${app.name} from ${app.primarySource}',
      button: true,
      selected: isSelected,
      child: AppCard(
        borderRadius: 16,
        color: isSelected && isDesktop
            ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.3)
            : null,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Hero(
              tag: heroTag,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  app.icon != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: app.icon!,
                            width: 40,
                            height: 40,
                            memCacheWidth: 80,
                            errorWidget: (c, e, s) => const Icon(Icons.apps),
                          ),
                        )
                      : const Icon(Icons.apps, size: 40),
                  SmoothSizeSwitcher(
                    alignment: Alignment.center,
                    child: isCurrentTask
                        ? Container(
                            key: const ValueKey('task_active'),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Skeleton(
                                width: 24,
                                height: 24,
                                borderRadius: 12,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('task_idle')),
                  ),
                ],
              ),
            ),
            title: Text(
              app.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: isCurrentTask
                ? Selector<TaskController, ({String status, double? progress})>(
                    selector: (context, c) =>
                        (status: c.status, progress: c.progress),
                    builder: (context, data, child) {
                      return Text(
                        "${data.status} ${data.progress != null ? '(${(data.progress! * 100).toInt()}%)' : ''}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  )
                : Text(
                    app.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: isCurrentTask
                ? Selector<TaskController, String>(
                    selector: (context, c) => c.speed,
                    builder: (context, speed, child) {
                      return Text(
                        speed,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      );
                    },
                  )
                : AppSourceTag(
                    source: app.primarySource,
                    mode: AppSourceTagMode.source,
                  ),
          ),
        ),
      ),
    );
  }
}
