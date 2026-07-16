import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/backend_service.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/features/task_manager/presentation/widgets/terminal_dialog.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

class StorageCleanupCard extends StatefulWidget {
  const StorageCleanupCard({super.key});

  @override
  State<StorageCleanupCard> createState() => _StorageCleanupCardState();
}

class _StorageCleanupCardState extends State<StorageCleanupCard> {
  Map<String, dynamic>? _storageInfo;
  bool _loadingStorage = false;

  @override
  void initState() {
    super.initState();
    _fetchStorageInfo();
  }

  Future<void> _fetchStorageInfo() async {
    if (!mounted) return;
    setState(() => _loadingStorage = true);
    try {
      final info = await BackendService.instance.getStorageInfo();
      if (!mounted) return;
      setState(() {
        _storageInfo = info;
        _loadingStorage = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingStorage = false);
      }
    }
  }

  Future<void> _triggerCleanup(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final taskController = context.read<TaskController>();
    if (taskController.isBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.taskInProgress),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TerminalDialog(),
    );

    await taskController.runCleanSystem(l10n);
    if (!mounted) return;
    await _fetchStorageInfo();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SmoothSizeSwitcher(
              alignment: Alignment.topLeft,
              child: _loadingStorage
                  ? const Column(
                      key: ValueKey('loading'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: double.infinity, height: 14),
                        SizedBox(height: 12),
                        Skeleton(width: double.infinity, height: 8),
                        SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Skeleton(width: 150, height: 16),
                                  SizedBox(height: 8),
                                  Skeleton(width: 200, height: 12),
                                ],
                              ),
                            ),
                            Skeleton(width: 100, height: 40, borderRadius: 20),
                          ],
                        ),
                      ],
                    )
                  : _storageInfo != null
                  ? Column(
                      key: const ValueKey('loaded'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Disk Space
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.diskSpaceInfo(
                                ((_storageInfo!['disk_free'] ?? 0) /
                                        (1024 * 1024 * 1024))
                                    .toStringAsFixed(1),
                                ((_storageInfo!['disk_total'] ?? 0) /
                                        (1024 * 1024 * 1024))
                                    .toStringAsFixed(1),
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Semantics(
                              label: l10n.refresh,
                              button: true,
                              child: IconButton(
                                icon: const Icon(Icons.refresh_rounded),
                                onPressed: _fetchStorageInfo,
                                tooltip: l10n.refresh,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0,
                              end:
                                  ((_storageInfo!['disk_used'] ?? 0) /
                                          ((_storageInfo!['disk_total'] ?? 1) ==
                                                  0
                                              ? 1
                                              : (_storageInfo!['disk_total'] ??
                                                    1)))
                                      .toDouble(),
                            ),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Cache Info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${l10n.systemCleaningSubtitle}: ${((_storageInfo!['total_cache'] ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.cacheTypeInfo(
                                      ((_storageInfo!['pacman_cache'] ?? 0) /
                                              (1024 * 1024))
                                          .toStringAsFixed(1),
                                      ((_storageInfo!['flatpak_cache'] ?? 0) /
                                              (1024 * 1024))
                                          .toStringAsFixed(1),
                                      ((_storageInfo!['omnistore_cache'] ?? 0) /
                                              (1024 * 1024))
                                          .toStringAsFixed(1),
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () => _triggerCleanup(context, l10n),
                              icon: const Icon(Icons.delete_sweep_rounded),
                              label: Text(l10n.systemCleaning),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Text(
                      key: const ValueKey('empty'),
                      l10n.systemCleaningSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
