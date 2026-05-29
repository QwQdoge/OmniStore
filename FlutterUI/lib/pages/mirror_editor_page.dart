// lib/pages/mirror_editor_page.dart
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/backend_service.dart';

class MirrorEditorPage extends StatefulWidget {
  const MirrorEditorPage({super.key});

  @override
  State<MirrorEditorPage> createState() => _MirrorEditorPageState();
}

class _MirrorEditorPageState extends State<MirrorEditorPage> {
  List<String> _mirrors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMirrors();
  }

  Future<void> _loadMirrors() async {
    final mirrors = await BackendService.instance.getPacmanMirrors();
    if (!mounted) return;
    setState(() {
      _mirrors = mirrors;
      _loading = false;
    });
  }

  Future<void> _saveMirrors() async {
    await BackendService.instance.savePacmanMirrors(_mirrors);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.mirrorListSaved)),
    );
  }

  void _addMirror() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.addMirror),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: AppLocalizations.of(context)!.serverUrl),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(AppLocalizations.of(context)!.confirm)),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _mirrors.add(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.pacmanMirrorManagement)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _mirrors.length,
              itemBuilder: (context, index) {
                final mirror = _mirrors[index];
                return ListTile(
                  title: Text(mirror),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => setState(() => _mirrors.removeAt(index)),
                  ),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'save',
            onPressed: _saveMirrors,
            icon: const Icon(Icons.save),
            label: Text(AppLocalizations.of(context)!.save),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: _addMirror,
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.add),
          ),
        ],
      ),
    );
  }
}
