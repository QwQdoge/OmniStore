import "package:frontend/data/repositories/task_repository.dart";
import "package:provider/provider.dart";
import "package:frontend/features/settings/presentation/controllers/settings_controller.dart";
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';

class TweaksPage extends StatelessWidget {
  const TweaksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l10n.settings,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: Text(l10n.aiEnabled),
            value: settings.isAIEnabled,
            onChanged: (val) {
              final config = Map<String, dynamic>.from(settings.config);
              config['ai'] ??= {};
              config['ai']['enabled'] = val;
              settings.updateConfig(config);
            },
          ),
          ListTile(
            title: Text(l10n.systemCleaning),
            trailing: const Icon(Icons.delete_sweep_rounded),
            onTap: () {
              context.read<TaskRepository>().cleanSystem().listen((_) {});
            },
          ),
        ],
      ),
    );
  }
}
