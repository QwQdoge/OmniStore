import "package:frontend/data/repositories/config_repository.dart";
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

  @override
  void dispose() {
    _patController.dispose();
    super.dispose();
  }

  Future<void> _loadPat() async {
    final configRepo = context.read<ConfigRepository>();
    final config = await configRepo.loadConfig();
    if (!mounted) return;
    setState(() {
      _patController.text = config['github']?['pat'] ?? '';
    });
  }

  Future<void> _savePat() async {
    final pat = _patController.text.trim();
    if (pat.length > 255 || RegExp(r'[\x00-\x1F\x7F]').hasMatch(pat)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid Personal Access Token'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final configRepo = context.read<ConfigRepository>();
    final config = await configRepo.loadConfig();
    if (!mounted) return;
    config['github'] ??= {};
    config['github']['pat'] = pat;
    await configRepo.saveConfig(config);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.githubPatSaved),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.githubAuthTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _patController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.personalAccessToken,
                border: const OutlineInputBorder(),
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
