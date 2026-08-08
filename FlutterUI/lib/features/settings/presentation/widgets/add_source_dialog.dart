import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/backend_service.dart';
import '../controllers/settings_controller.dart';
import 'package:frontend/core/utils/toast.dart';

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
      Toast.show(context, widget.l10n.errorNameUrlRequired);
      return;
    }

    final settings = context.read<SettingsController>();
    Navigator.pop(context);

    Toast.show(context, widget.l10n.addingCustomSource);

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

    if (!mounted) return;

    Toast.show(
      context,
      success ? widget.l10n.sourceAddSuccess : widget.l10n.sourceAddFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      icon: Icon(
<<<<<<< HEAD
        Icons.add_circle_outline_rounded,
        color: Theme.of(context).colorScheme.primary,
=======
        Icons.add_link_rounded,
        color: theme.colorScheme.primary,
>>>>>>> origin/main
        size: 32,
      ),
      title: Text(
        widget.l10n.addCustomSource,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _type,
              borderRadius: BorderRadius.circular(12),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              decoration: InputDecoration(
                labelText: widget.l10n.sourceType,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: "github",
                  child: Text(widget.l10n.githubRepoType),
>>>>>>> origin/main
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _type,
                      borderRadius: BorderRadius.circular(12),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: widget.l10n.sourceName,
                hintText: widget.l10n.hintCustomAppName,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: _type == "github" || _type == "bitu"
                    ? widget.l10n.repoOwnerRepo
                    : widget.l10n.sourceUrl,
                hintText: _type == "github" || _type == "bitu"
                    ? widget.l10n.hintRepoFormat
                    : widget.l10n.hintFeedUrl,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
