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

  /// Murphy-proof: Safely loads configuration with try-catch and mounted guards.
  Future<void> _loadPat() async {
    try {
      final configRepo = context.read<ConfigRepository>();
      final config = await configRepo.loadConfig();
      if (!mounted) return;
      setState(() {
        _patController.text = config['github']?['pat'] ?? '';
      });
    } catch (e) {
      debugPrint("Murphy-proof Error: Failed to load GitHub PAT: $e");
    }
  }

  /// Murphy-proof: Safely saves configuration with try-catch, validation, and standardized SnackBar duration.
  Future<void> _savePat() async {
    final rawText = _patController.text.trim();

    // 1. Extreme Input Parameter Validation & Boundary Defense
    if (rawText.length > 255) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error: GitHub PAT is too long (maximum 255 characters)."),
            duration: Duration(seconds: 2), // Standardized to 2 seconds
          ),
        );
      }
      return;
    }

    // Checking for potentially unsafe ASCII control characters or shell metacharacters
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(rawText)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error: GitHub PAT contains invalid control characters."),
            duration: Duration(seconds: 2), // Standardized to 2 seconds
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
      config['github']['pat'] = rawText;

      await configRepo.saveConfig(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.githubPatSaved),
            duration: const Duration(seconds: 2), // Standardized to 2 seconds
          ),
        );
      }
    } catch (e) {
      debugPrint("Murphy-proof Error: Failed to save GitHub PAT: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: Failed to save GitHub PAT: $e"),
            duration: const Duration(seconds: 2), // Standardized to 2 seconds
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.githubAuthTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _patController,
              decoration: InputDecoration(
                labelText: l10n.personalAccessToken,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _savePat,
              child: Text(l10n.saveToken),
            ),
          ],
        ),
      ),
    );
  }
}
