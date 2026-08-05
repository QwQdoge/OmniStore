import "package:frontend/data/repositories/config_repository.dart";
import "package:provider/provider.dart";
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';

/// [GitHubIntegrationPage] provides a fail-safe user interface for modifying the GitHub personal
/// access token (PAT). It employs defensive try-catch-finally flows, input sanitization
/// and validation, and state mutex locks to guarantee robustness under bad environment conditions.
class GitHubIntegrationPage extends StatefulWidget {
  const GitHubIntegrationPage({super.key});

  @override
  State<GitHubIntegrationPage> createState() => _GitHubIntegrationPageState();
}

class _GitHubIntegrationPageState extends State<GitHubIntegrationPage> {
  final TextEditingController _patController = TextEditingController();
  bool _isSaving = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Safely load token after the current frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPat();
      }
    });
  }

  @override
  void dispose() {
    // Prevent memory leak by disposing controller.
    _patController.dispose();
    super.dispose();
  }

  /// Loads the saved PAT from the configuration store.
  /// Wrapped in a try-catch to avoid app crashes if the YAML config file is corrupted.
  Future<void> _loadPat() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final configRepo = context.read<ConfigRepository>();
      final config = await configRepo.loadConfig();
      if (!mounted) return;

      final dynamic githubSection = config['github'];
      String pat = '';
      if (githubSection is Map) {
        pat = (githubSection['pat'] ?? '').toString();
      }

      setState(() {
        _patController.text = pat;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading GitHub PAT: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load GitHub token: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Validates and saves the personal access token.
  /// Uses try-catch-finally to ensure the saving lock state is always released,
  /// preventing infinite button lockout.
  Future<void> _savePat() async {
    if (_isSaving || _isLoading) return;

    // Defensive check: validate and sanitize input arguments
    final String rawInput = _patController.text;
    final String tokenText = rawInput.trim();

    if (tokenText.isNotEmpty) {
      // Validate string characters (ensure basic ASCII range to prevent YAML parser corruptions)
      final asciiRegExp = RegExp(r'^[\x20-\x7E]*$');
      if (!asciiRegExp.hasMatch(tokenText)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Token contains invalid or non-printable characters.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Check for extremely long tokens that could crash memory or file storage
      if (tokenText.length > 512) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Token length exceeds safety limit of 512 characters.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final configRepo = context.read<ConfigRepository>();
      final config = await configRepo.loadConfig();
      if (!mounted) return;

      config['github'] ??= {};
      if (config['github'] is Map) {
        config['github']['pat'] = tokenText;
      } else {
        // Safe recovery if the underlying type was corrupted
        config['github'] = {'pat': tokenText};
      }

      await configRepo.saveConfig(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.githubPatSaved),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error saving GitHub PAT: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Failed to save GitHub token: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // State rollback is guaranteed to run even if write operation throws an exception.
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isInteractive = !_isSaving && !_isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text("GitHub Integration"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _patController,
              enabled: isInteractive,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.personalAccessToken,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.vpn_key_rounded),
                helperText: 'Provide a GitHub Classic PAT or Fine-grained Token.',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isLoading || _isSaving)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: isInteractive ? _savePat : null,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(l10n.saveToken),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
