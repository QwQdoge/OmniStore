import 'dart:async';
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

  /// Murphy-proof: Safely load GitHub PAT configuration with error boundaries and timeouts.
  Future<void> _loadPat() async {
    try {
      final configRepo = context.read<ConfigRepository>();
      final config = await configRepo.loadConfig().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException("Configuration loading timed out"),
      );
      if (!mounted) return;
      setState(() {
        _patController.text = config['github']?['pat'] ?? '';
      });
    } catch (e) {
      debugPrint("Murphy-proof Warning: Failed to load PAT: $e");
      if (mounted) {
        _showErrorSnackBar("Failed to load GitHub configuration: ${e.toString()}");
      }
    }
  }

  /// Murphy-proof: Safely save GitHub PAT configuration with extreme input validation,
  /// state locking, error boundaries, and timeouts.
  Future<void> _savePat() async {
    final rawToken = _patController.text.trim();

    // 1. Extreme input validation (Requirement 3: 入参极端校验)
    if (rawToken.isNotEmpty) {
      if (rawToken.length > 255) {
        _showErrorSnackBar("Token exceeds maximum allowed length of 255 characters.");
        return;
      }
      if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(rawToken)) {
        _showErrorSnackBar("Token contains invalid control characters.");
        return;
      }
    }

    // 2. State locking (Requirement 3: 状态互斥防护)
    setState(() => _isSaving = true);

    try {
      final configRepo = context.read<ConfigRepository>();
      final config = await configRepo.loadConfig().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException("Configuration loading timed out"),
      );
      if (!mounted) return;

      config['github'] ??= {};
      config['github']['pat'] = rawToken;

      await configRepo.saveConfig(config).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException("Configuration saving timed out"),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.githubPatSaved),
            duration: const Duration(seconds: 4), // complies with Material Design 3 guidelines for informational SnackBars
          ),
        );
      }
    } catch (e) {
      // 3. Defensive exception catching and fault isolation (Requirement 1: 故障隔离与防雪崩)
      debugPrint("Murphy-proof Error: Failed to save GitHub PAT: $e");
      if (mounted) {
        _showErrorSnackBar("Failed to save token: ${e.toString()}");
      }
    } finally {
      // 4. Ensure state-mutex is always unlocked (Requirement 1 & 3: 锁释放/不卡死)
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Murphy-proof: Centralized UI error notification.
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4), // complies with "SnackBar Duration" guideline
      ),
    );
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
