import "package:frontend/data/repositories/config_repository.dart";
import "package:provider/provider.dart";
import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/utils/toast.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPat();
    });
  }

  @override
  void dispose() {
    _patController.dispose();
    super.dispose();
  }

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
      setState(() => _patController.text = pat);
    } catch (e, stackTrace) {
      debugPrint('Error loading GitHub PAT: $e\n$stackTrace');
      if (mounted) Toast.show(context, 'Failed to load GitHub token: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePat() async {
    if (_isSaving || _isLoading) return;

    final tokenText = _patController.text.trim();
    if (tokenText.isNotEmpty) {
      final asciiRegExp = RegExp(r'^[\x20-\x7E]*$');
      if (!asciiRegExp.hasMatch(tokenText)) {
        if (mounted) {
          Toast.show(context, 'Error: Token contains invalid or non-printable characters.');
        }
        return;
      }
      if (tokenText.length > 512) {
        if (mounted) {
          Toast.show(context, 'Error: Token length exceeds safety limit of 512 characters.');
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
        config['github'] = {'pat': tokenText};
      }
      await configRepo.saveConfig(config);

      if (mounted) {
        Toast.show(context, AppLocalizations.of(context)!.githubPatSaved);
      }
    } catch (e, stackTrace) {
      debugPrint('Error saving GitHub PAT: $e\n$stackTrace');
      if (mounted) Toast.show(context, 'Error: Failed to save GitHub token: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isInteractive = !_isSaving && !_isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.githubAuthTitle)),
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
                  vertical: 14,
                ),
                prefixIcon: const Icon(Icons.vpn_key_rounded),
                helperText: 'Provide a GitHub Classic PAT or Fine-grained Token.',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: isInteractive ? _savePat : null,
                  icon: SmoothSizeSwitcher(
                    child: (_isLoading || _isSaving)
                        ? const SizedBox(
                            key: ValueKey('loading'),
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded, key: ValueKey('idle')),
                  ),
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
