import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/task_state.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/core/widgets/smooth_progress_bar.dart';

class AppDetailsActions extends StatelessWidget {
  final String appName;
  final bool isAppInstalled;
  final VoidCallback onLocateApp;
  final ValueChanged<String> onHandleAction;
  final VoidCallback onLaunchApp;
  final VoidCallback onCancelAction;

  const AppDetailsActions({
    super.key,
    required this.appName,
    required this.isAppInstalled,
    required this.onLocateApp,
    required this.onHandleAction,
    required this.onLaunchApp,
    required this.onCancelAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    Widget content;

    if (context.select((TaskController task) => task.isBusy)) {
      content = Container(
        key: const ValueKey('busy'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child:
            Selector<
              TaskController,
              ({double? progress, String status, String speed})
            >(
              selector: (context, c) =>
                  (progress: c.progress, status: c.status, speed: c.speed),
              builder: (context, data, _) => SmoothProgressBar(
                taskState: TaskState(
                  id: "active",
                  packageName: appName,
                  status: TaskStatus.downloading,
                  progress: data.progress ?? 0.0,
                  stage: data.status,
                  speed: data.speed,
                ),
                onCancel: onCancelAction,
              ),
            ),
      );
    } else if (isAppInstalled) {
      content = Row(
        key: const ValueKey('installed'),
        children: [
          Semantics(
            label: AppLocalizations.of(context)!.locateInstallation,
            button: true,
            child: IconButton.filledTonal(
              onPressed: onLocateApp,
              icon: const Icon(Icons.folder_open_rounded),
              tooltip: AppLocalizations.of(context)!.locateInstallation,
              style: IconButton.styleFrom(
                minimumSize: const Size(56, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 56,
              child: Semantics(
                label: AppLocalizations.of(context)!.uninstall,
                button: true,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(
                      color: colorScheme.error.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                  ),
                  onPressed: () => onHandleAction("-R"),
                  child: Text(
                    AppLocalizations.of(context)!.uninstall,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 56,
              child: Semantics(
                label: AppLocalizations.of(context)!.launch,
                button: true,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                  ),
                  onPressed: onLaunchApp,
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: Text(
                    AppLocalizations.of(context)!.launch,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      content = SizedBox(
        key: const ValueKey('install'),
        width: double.infinity,
        height: 56,
        child: Semantics(
          label: AppLocalizations.of(context)!.install,
          button: true,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
            onPressed: () => onHandleAction("-I"),
            icon: const Icon(Icons.download_rounded),
            label: Text(
              AppLocalizations.of(context)!.install,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.fastOutSlowIn,
        child: content,
      ),
    );
  }
}
