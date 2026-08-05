import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_card.dart';
import '../controllers/settings_controller.dart';

class TypographySettingsCard extends StatelessWidget {
  const TypographySettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Selector<
      SettingsController,
      ({String fontFamily, double fontScale})
    >(
      selector: (context, s) =>
          (fontFamily: s.fontFamily, fontScale: s.fontScale),
      builder: (context, data, _) {
        return AppCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.font_download_rounded),
                title: Text(l10n.fontFamily),
                subtitle: Text(
                  data.fontFamily == 'System'
                      ? l10n.systemDefault
                      : data.fontFamily,
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: data.fontFamily,
                      borderRadius: BorderRadius.circular(12),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'System',
                          child: Text(l10n.systemDefault),
                        ),
                        const DropdownMenuItem(
                          value: 'Inter',
                          child: Text('Inter'),
                        ),
                        const DropdownMenuItem(
                          value: 'Roboto',
                          child: Text('Roboto'),
                        ),
                        const DropdownMenuItem(
                          value: 'Outfit',
                          child: Text('Outfit'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          context.read<SettingsController>().setFontFamily(val);
                        }
                      },
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.format_size_rounded),
                title: Text(l10n.fontScale),
                subtitle: Text("${(data.fontScale * 100).toInt()}%"),
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: data.fontScale,
                    min: 0.8,
                    max: 1.6,
                    divisions: 8,
                    label: "${(data.fontScale * 100).toInt()}%",
                    onChanged: (val) {
                      context.read<SettingsController>().setFontScale(
                        double.parse(val.toStringAsFixed(2)),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
