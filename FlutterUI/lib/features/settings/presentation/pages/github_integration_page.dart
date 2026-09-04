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
  bool _showPat = false;

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
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isInteractive = !_isSaving && !_isLoading;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: colorScheme.primary,
        width: 2,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.githubAuthTitle),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: AutofillGroup(
                  onDisposeAction: AutofillContextAction.cancel,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.7,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.code_rounded,
                            size: 40,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.githubIntegration,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.configurePat,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _patController,
                        enabled: isInteractive,
                        obscureText: !_showPat,
                        autofillHints: const [
                          AutofillHints.password,
                        ],
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: l10n.personalAccessToken,
                          border: border,
                          enabledBorder: border,
                          focusedBorder: focusedBorder,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          prefixIcon: const Icon(Icons.vpn_key_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPat
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                            tooltip: _showPat
                                ? l10n.hidePassword
                                : l10n.showPassword,
                            onPressed: () {
                              setState(() {
                                _showPat = !_showPat;
                              });
                            },
                          ),
                          helperText: l10n.patHelperText,
                        ),
                        onSubmitted: (_) {
                          if (isInteractive) {
                            _savePat();
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton.icon(
                            onPressed: isInteractive ? _savePat : null,
                            icon: SmoothSizeSwitcher(
                              child: (_isLoading || _isSaving)
                                  ? SizedBox(
                                      key: const ValueKey('loading'),
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onPrimary,
                                      ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
