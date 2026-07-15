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
                trailing: DropdownButton<String>(
                  value: data.fontFamily,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(12),
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
