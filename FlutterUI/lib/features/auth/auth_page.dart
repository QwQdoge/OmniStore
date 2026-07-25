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
      debugPrint('Murphy-proof Error: Failed to load PAT: $e');
    }
  }

  Future<void> _savePat() async {
    if (_isSaving) return; // Mutex protection

    final token = _patController.text.trim();

    // Foolproof Input Validation: Limit maximum length to 255 characters
    if (token.length > 255) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid token: maximum length is 255 characters.'),
            duration: Duration(seconds: 2), // Standardized to 2 seconds for visual UX consistency
          ),
        );
      }
      return;
    }

    // Foolproof Input Validation: Strictly deny control characters to prevent shell injection/pipe breaking
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(token)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid token: contains illegal control characters.'),
            duration: Duration(seconds: 2), // Standardized to 2 seconds for visual UX consistency
          ),
        );
      }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.githubPatSaved),
            duration: const Duration(seconds: 2), // Standardized to 2 seconds for visual UX consistency
          ),
        );
      }
    } catch (e) {
      debugPrint('Murphy-proof Error: Failed to save PAT: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save PAT: $e'),
            duration: const Duration(seconds: 2), // Standardized to 2 seconds for visual UX consistency
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
