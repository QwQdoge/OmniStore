import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/backend_service.dart';
import '../controllers/settings_controller.dart';

class AddSourceDialog extends StatefulWidget {
  final AppLocalizations l10n;

  const AddSourceDialog({super.key, required this.l10n});

  @override
  State<AddSourceDialog> createState() => _AddSourceDialogState();
}

class _AddSourceDialogState extends State<AddSourceDialog> {
  String _type = "github";
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    if (name.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.l10n.errorNameUrlRequired),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final settings = context.read<SettingsController>();
    Navigator.pop(context);

    messenger.showSnackBar(
      SnackBar(
        content: Text(widget.l10n.addingCustomSource),
        duration: const Duration(seconds: 4),
      ),
    );

    bool success = false;
    if (kIsWeb) {
      final config = Map<String, dynamic>.from(settings.config);
      config['custom_repos'] = Map<String, dynamic>.from(
        config['custom_repos'] ?? {},
      );
      config['custom_repos'][_type] = List<dynamic>.from(
        config['custom_repos'][_type] ?? [],
      );
      config['custom_repos'][_type].add({"name": name, "url": url});
      success = await settings.updateConfig(config);
    } else {
      final result = await BackendService.instance.addCustomRepo(
        _type,
        name,
        url,
      );
      success = result;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? widget.l10n.sourceAddSuccess : widget.l10n.sourceAddFailed,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.addCustomSource),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(labelText: widget.l10n.sourceType),
              items: [
                DropdownMenuItem(
                  value: "github",
                  child: Text(widget.l10n.githubRepoType),
                ),
                DropdownMenuItem(
                  value: "bitu",
                  child: Text(widget.l10n.bituRepoType),
                ),
                DropdownMenuItem(
                  value: "flatpak",
                  child: Text(widget.l10n.flatpakRemoteType),
                ),
                DropdownMenuItem(
                  value: "appimage",
                  child: Text(widget.l10n.appImageFeedType),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _type = val);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: widget.l10n.sourceName,
                hintText: widget.l10n.hintCustomAppName,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: _type == "github" || _type == "bitu"
                    ? widget.l10n.repoOwnerRepo
                    : widget.l10n.sourceUrl,
                hintText: _type == "github" || _type == "bitu"
                    ? widget.l10n.hintRepoFormat
                    : widget.l10n.hintFeedUrl,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.l10n.cancel),
        ),
        FilledButton(onPressed: _handleAdd, child: Text(widget.l10n.add)),
      ],
    );
  }
}
