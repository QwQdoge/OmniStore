import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_card.dart';
import '../controllers/settings_controller.dart';

class UpdateSettingsCard extends StatelessWidget {
  const UpdateSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Selector<
      SettingsController,
      ({
        bool daemonEnabled,
        bool autoUpdate,
        bool enableSystemdService,
        int checkIntervalHours,
      })
    >(
      selector: (context, s) => (
        daemonEnabled: s.daemonEnabled,
        autoUpdate: s.autoUpdate,
        enableSystemdService: s.enableSystemdService,
        checkIntervalHours: s.checkIntervalHours,
      ),
      builder: (context, data, _) {
        return AppCard(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.settings_suggest_rounded),
                title: Text(l10n.enableDaemon),
                subtitle: Text(l10n.enableDaemonDesc),
                value: data.daemonEnabled,
                onChanged: (val) {
                  context.read<SettingsController>().setDaemonEnabled(val);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.auto_mode_rounded),
                title: Text(l10n.autoUpdate),
                subtitle: Text(l10n.autoUpdateDesc),
                value: data.autoUpdate,
                onChanged: (val) {
                  context.read<SettingsController>().setAutoUpdate(val);
                },
              ),
              if (Platform.isLinux)
                SwitchListTile(
                  secondary: const Icon(Icons.terminal_rounded),
                  title: Text(l10n.enableSystemdService),
                  subtitle: Text(l10n.enableSystemdServiceDesc),
                  value: data.enableSystemdService,
                  onChanged: (val) {
                    context.read<SettingsController>().setEnableSystemdService(val);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.timer_rounded),
                title: Text(l10n.checkIntervalTitle),
                subtitle: Text(l10n.checkIntervalSubtitle(data.checkIntervalHours)),
                trailing: DropdownButton<int>(
                  value: data.checkIntervalHours,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(12),
                  items: [1, 2, 4, 8, 12, 24].map((h) {
                    return DropdownMenuItem(
                      value: h,
                      child: Text(l10n.hourValue(h)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      context.read<SettingsController>().setCheckIntervalHours(val);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
