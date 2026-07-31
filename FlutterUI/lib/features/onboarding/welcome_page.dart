import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/services/backend_service.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

class WelcomePage extends StatefulWidget {
  final VoidCallback onFinish;
  const WelcomePage({super.key, required this.onFinish});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Software sources configuration
  bool _enableAur = false;

  // AI assistant configuration
  bool _enableAI = false;
  String _aiProvider = 'ollama';
  final TextEditingController _aiEndpointController = TextEditingController(text: 'http://localhost:11434');
  final TextEditingController _aiApiKeyController = TextEditingController();

  // Environment check state
  bool _isCheckingEnv = false;
  Map<String, dynamic>? _envData;

  // Bootstrap (system fix) state
  bool _isBootstrapping = false;
  String _bootstrapLogs = '';
  StreamSubscription<String>? _bootstrapSub;
  final ScrollController _terminalScrollController = ScrollController();

  // AI connection test state
  bool _isTestingAI = false;
  String? _aiTestResult;
  bool _aiTestSuccess = false;

  @override
  void initState() {
    super.initState();
    _aiEndpointController.addListener(_onAiConfigChanged);
    _aiApiKeyController.addListener(_onAiConfigChanged);
  }

  @override
  void dispose() {
    _aiEndpointController.dispose();
    _aiApiKeyController.dispose();
    _bootstrapSub?.cancel();
    _terminalScrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onAiConfigChanged() {
    if (_aiTestResult != null) {
      setState(() {
        _aiTestResult = null;
      });
    }
  }

  Future<void> _checkEnvironment() async {
    if (_isCheckingEnv) return;
    setState(() {
      _isCheckingEnv = true;
      _envData = null;
    });
    try {
      final env = await BackendService.instance.checkEnv();
      setState(() {
        _envData = env;
        _isCheckingEnv = false;
        // Determine whether yay/AUR helpers are missing, and auto-toggle enableAur if ok
        final level = _evaluateEnvLevel(env);
        _enableAur = level == 'ok';
      });
    } catch (e) {
      setState(() {
        _envData = null;
        _isCheckingEnv = false;
      });
    }
  }

  String _evaluateEnvLevel(Map<String, dynamic> env) {
    bool hasFatal = false;
    bool hasWarning = false;
    env.forEach((key, val) {
      if (val is Map && val['status'] != null) {
        final status = val['status'].toString();
        if (status == 'fatal') hasFatal = true;
        if (status == 'warning') hasWarning = true;
      }
    });
    if (hasFatal) return 'fatal';
    if (hasWarning) return 'warning';
    return 'ok';
  }

  void _startBootstrap() {
    if (_isBootstrapping) return;
    setState(() {
      _isBootstrapping = true;
      _bootstrapLogs = 'Initializing system configuration bootstrap...\n';
    });

    _bootstrapSub = BackendService.instance.bootstrap().listen(
      (data) {
        _parseBootstrapLine(data);
      },
      onError: (err) {
        setState(() {
          _bootstrapLogs += '\n[ERROR] Bootstrap failed: $err\n';
          _isBootstrapping = false;
        });
      },
      onDone: () {
        setState(() {
          _bootstrapLogs += '\n[INFO] Configuration sequence completed.\n';
          _isBootstrapping = false;
        });
        _checkEnvironment();
      },
    );
  }

  void _parseBootstrapLine(String line) {
    final cleanLine = line.trim();
    if (cleanLine.isEmpty) return;

    if (cleanLine.startsWith('[CALLBACK]')) {
      final jsonStr = cleanLine.replaceFirst('[CALLBACK]', '').trim();
      try {
        final data = jsonDecode(jsonStr);
        if (data is Map<String, dynamic>) {
          String? message = data['log'] ?? data['message'];
          if (message != null) {
            setState(() {
              _bootstrapLogs += '$message\n';
            });
            _scrollToBottom();
          }
        }
        return;
      } catch (_) {}
    }

    if (cleanLine.startsWith('[PROGRESS]')) return;

    if (cleanLine.startsWith('[ERROR]')) {
      final msg = cleanLine.replaceFirst('[ERROR]', '').trim();
      setState(() {
        _bootstrapLogs += '[ERROR] $msg\n';
      });
    } else if (cleanLine.startsWith('[INFO]')) {
      final msg = cleanLine.replaceFirst('[INFO]', '').trim();
      setState(() {
        _bootstrapLogs += '[INFO] $msg\n';
      });
    } else {
      setState(() {
        _bootstrapLogs += '$cleanLine\n';
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_terminalScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_terminalScrollController.hasClients) {
          _terminalScrollController.animateTo(
            _terminalScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _testAIConnection() async {
    if (_isTestingAI) return;
    setState(() {
      _isTestingAI = true;
      _aiTestResult = null;
      _aiTestSuccess = false;
    });

    final settings = context.read<SettingsController>();
    final originalConfig = Map<String, dynamic>.from(settings.config);

    final testConfig = Map<String, dynamic>.from(originalConfig);
    testConfig['ai'] = testConfig['ai'] ?? {};
    testConfig['ai']['enabled'] = true;
    testConfig['ai']['provider'] = _aiProvider;
    testConfig['ai']['endpoint'] = _aiEndpointController.text.trim();
    testConfig['ai']['api_key'] = _aiApiKeyController.text.trim();

    await settings.updateConfig(testConfig);

    try {
      final result = await BackendService.instance.testAiConnection();
      final status = result['status']?.toString();
      final response = result['response']?.toString() ?? '';

      setState(() {
        if (status == 'success' || response.toLowerCase().contains('ok') || response.toLowerCase().contains('success')) {
          _aiTestSuccess = true;
          _aiTestResult = 'Connection successful!';
        } else {
          _aiTestSuccess = false;
          _aiTestResult = 'Connection failed: $response';
        }
      });
    } catch (e) {
      setState(() {
        _aiTestSuccess = false;
        _aiTestResult = 'Error: $e';
      });
    } finally {
      await settings.updateConfig(originalConfig);
      setState(() {
        _isTestingAI = false;
      });
    }
  }

  Future<void> _finishOnboarding() async {
    final settingsController = context.read<SettingsController>();
    final config = Map<String, dynamic>.from(settingsController.config);

    config['first_run'] = false;

    config['search'] = config['search'] ?? {};
    config['search']['sources'] = config['search']['sources'] ?? {};
    config['search']['sources']['aur'] = _enableAur;

    config['ai'] = config['ai'] ?? {};
    config['ai']['enabled'] = _enableAI;
    config['ai']['provider'] = _aiProvider;
    config['ai']['endpoint'] = _aiEndpointController.text.trim();
    config['ai']['api_key'] = _aiApiKeyController.text.trim();

    await settingsController.updateConfig(config);
    widget.onFinish();
  }

  void _onPageChanged(int idx) {
    setState(() {
      _currentPage = idx;
    });
    if (idx == 1 && _envData == null) {
      _checkEnvironment();
    }
  }

  Widget _buildConfigCard({
    required Widget child,
    required ThemeData theme,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 0.3,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: [
                    _buildIntroPage(l10n, theme),
                    _buildEnvCheckPage(l10n, theme),
                    _buildSourcesPage(l10n, theme),
                    _buildAiPage(l10n, theme),
                  ],
                ),
              ),
              _buildBottomBar(l10n, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroPage(AppLocalizations l10n, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 80),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.rocket_launch_rounded,
              size: 64,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            l10n.welcomeTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.welcomeSubtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildEnvCheckPage(AppLocalizations l10n, ThemeData theme) {
    final level = _envData != null ? _evaluateEnvLevel(_envData!) : 'unknown';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.envCheckTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.envCheckSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SmoothSizeSwitcher(
            alignment: Alignment.topCenter,
            child: _isCheckingEnv
                ? Center(
                    key: const ValueKey('checking'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Checking environment status...',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                : _envData == null
                    ? Center(
                        key: const ValueKey('error'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to fetch environment details.',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _checkEnvironment,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        key: const ValueKey('content'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEnvStatusHeader(level, l10n, theme),
                          const SizedBox(height: 20),
                          if (level == 'warning') ...[
                            _buildConfigCard(
                              theme: theme,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          size: 18,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            l10n.bootstrapNote,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _isBootstrapping ? null : _startBootstrap,
                                        icon: const Icon(Icons.build_rounded),
                                        label: Text(l10n.fixProblems),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_isBootstrapping || _bootstrapLogs.isNotEmpty) ...[
                            Text(
                              'Bootstrap progress:',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_isBootstrapping) ...[
                              const LinearProgressIndicator(),
                              const SizedBox(height: 8),
                            ],
                            Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                  width: 0.5,
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: SingleChildScrollView(
                                controller: _terminalScrollController,
                                child: SelectableText(
                                  _bootstrapLogs,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            'System details:',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildEnvDetailsGrid(_envData!, theme),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvStatusHeader(String level, AppLocalizations l10n, ThemeData theme) {
    final IconData icon;
    final Color color;
    final String text;

    if (level == 'ok') {
      icon = Icons.check_circle_rounded;
      color = theme.colorScheme.primary;
      text = l10n.envOkDesc;
    } else if (level == 'warning') {
      icon = Icons.warning_amber_rounded;
      color = Colors.orange;
      text = l10n.envWarningDesc;
    } else {
      icon = Icons.error_outline_rounded;
      color = theme.colorScheme.error;
      text = l10n.envFatalDesc;
    }

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvDetailsGrid(Map<String, dynamic> env, ThemeData theme) {
    return Column(
      children: env.entries.map((entry) {
        final key = entry.key;
        final val = entry.value;
        if (val is! Map) return const SizedBox.shrink();

        final String message = val['message']?.toString() ?? key;
        final String status = val['status']?.toString() ?? 'unknown';

        final IconData icon;
        final Color color;

        if (status == 'ok') {
          icon = Icons.check_rounded;
          color = theme.colorScheme.primary;
        } else if (status == 'warning') {
          icon = Icons.info_outline_rounded;
          color = Colors.orange;
        } else {
          icon = Icons.close_rounded;
          color = theme.colorScheme.error;
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                status.toUpperCase(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSourcesPage(AppLocalizations l10n, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sourceConfigTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.sourceConfigSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildConfigCard(
            theme: theme,
            child: SwitchListTile(
              title: Text(
                l10n.enableAur,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(l10n.yayDesc),
              value: _enableAur,
              onChanged: (val) {
                setState(() {
                  _enableAur = val;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          SmoothSizeSwitcher(
            alignment: Alignment.topCenter,
            child: _enableAur
                ? Card(
                    key: const ValueKey('aur-warning'),
                    elevation: 0,
                    color: theme.colorScheme.errorContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.security_rounded,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.aurWarning,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('aur-empty')),
          ),
        ],
      ),
    );
  }

  Widget _buildAiPage(AppLocalizations l10n, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.aiAssistant,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.aiAssistantDesc,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildConfigCard(
            theme: theme,
            child: SwitchListTile(
              title: Text(
                l10n.aiAssistant,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Enable intelligence integration features'),
              value: _enableAI,
              onChanged: (val) {
                setState(() {
                  _enableAI = val;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          SmoothSizeSwitcher(
            alignment: Alignment.topCenter,
            child: _enableAI
                ? Column(
                    key: const ValueKey('ai-details'),
                    children: [
                      _buildConfigCard(
                        theme: theme,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.aiProviderDesc,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _aiProvider,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'ollama',
                                    child: Text('Ollama (Local / Offline)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'openai',
                                    child: Text('OpenAI API (Cloud)'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _aiProvider = val;
                                      if (val == 'ollama') {
                                        _aiEndpointController.text = 'http://localhost:11434';
                                      } else {
                                        _aiEndpointController.text = 'https://api.openai.com/v1';
                                      }
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _aiEndpointController,
                                decoration: InputDecoration(
                                  labelText: 'Endpoint URL',
                                  hintText: _aiProvider == 'ollama'
                                      ? l10n.aiEndpointHelper
                                      : 'e.g. https://api.openai.com/v1',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _aiApiKeyController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'API Key',
                                  hintText: l10n.aiApiKeyHelper,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      _showApiKeyInstructions(l10n, theme);
                                    },
                                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                                    label: Text(l10n.howToGetApiKey),
                                  ),
                                  const Spacer(),
                                  _isTestingAI
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : FilledButton.tonalIcon(
                                          onPressed: _testAIConnection,
                                          icon: const Icon(Icons.network_ping_rounded, size: 18),
                                          label: const Text('Test Connection'),
                                        ),
                                ],
                              ),
                              if (_aiTestResult != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _aiTestSuccess
                                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                        : theme.colorScheme.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _aiTestSuccess
                                          ? theme.colorScheme.primary.withValues(alpha: 0.3)
                                          : theme.colorScheme.error.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _aiTestSuccess
                                            ? Icons.check_circle_rounded
                                            : Icons.error_outline_rounded,
                                        size: 18,
                                        color: _aiTestSuccess
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _aiTestResult!,
                                          style: TextStyle(
                                            color: _aiTestSuccess
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.error,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (_aiProvider == 'ollama') ...[
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.aiOllamaNote,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('ai-empty')),
          ),
        ],
      ),
    );
  }

  void _showApiKeyInstructions(AppLocalizations l10n, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                l10n.howToGetApiKey,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Text(
            l10n.howToGetApiKeyDesc,
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentPage > 0)
            TextButton.icon(
              onPressed: _isBootstrapping
                  ? null
                  : () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                      );
                    },
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(l10n.back),
            ),
          const Spacer(),
          Text(
            'Step ${_currentPage + 1} of 4',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _isBootstrapping
                ? null
                : () {
                    if (_currentPage < 3) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                      );
                    } else {
                      _finishOnboarding();
                    }
                  },
            icon: Icon(
              _currentPage < 3 ? Icons.arrow_forward_rounded : Icons.login_rounded,
              size: 18,
            ),
            label: Text(
              _currentPage == 0
                  ? l10n.getStarted
                  : _currentPage < 3
                      ? l10n.next
                      : l10n.enterStore,
            ),
          ),
        ],
      ),
    );
  }
}
