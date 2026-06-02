import "package:frontend/backend/repositories/config_repository.dart";
import "package:provider/provider.dart";
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _patController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPat());
  }

  Future<void> _loadPat() async {
    final configRepo = context.read<ConfigRepository>();
    final config = await configRepo.loadConfig();
    if (mounted) {
      setState(() {
        _patController.text = config['github']?['pat'] ?? '';
      });
    }
  }

  Future<void> _savePat() async {
    setState(() => _isSaving = true);
    final configRepo = context.read<ConfigRepository>();
    final config = await configRepo.loadConfig();
    config['github'] ??= {};
    config['github']['pat'] = _patController.text.trim();
    await configRepo.saveConfig(config);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.githubPatSaved)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.githubAuthTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _patController,
              decoration: const InputDecoration(
                labelText: "Personal Access Token",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _savePat,
              child: Text(AppLocalizations.of(context)!.saveToken),
            ),
          ],
        ),
      ),
    );
  }
}
