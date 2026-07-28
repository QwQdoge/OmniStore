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
    try {
      final configRepo = context.read<ConfigRepository>();
      final config = await configRepo.loadConfig();
      if (!mounted) return;
      setState(() {
        _patController.text = config['github']?['pat'] ?? '';
      });
    } catch (e) {
      debugPrint('Error loading PAT config: $e');
    }
  }

  Future<void> _savePat() async {
    final String token = _patController.text.trim();

    // Input security validation: check length limit and control characters
    if (token.length > 255) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Token is too long (maximum 255 characters).'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final RegExp controlCharPattern = RegExp(r'[\x00-\x1F\x7F]');
    if (controlCharPattern.hasMatch(token)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Token contains invalid control characters.'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final configRepo = context.read<ConfigRepository>();
      final config = await configRepo.loadConfig();
      if (!mounted) return;
      config['github'] ??= {};
      config['github']['pat'] = token;
      await configRepo.saveConfig(config);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.githubPatSaved),
            duration: const Duration(seconds: 2), // Standardized to 2 seconds
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving PAT config: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save Personal Access Token.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
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
