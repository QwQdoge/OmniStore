import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/services/backend_service.dart';
import 'widgets/intro_page.dart';
import 'widgets/env_check_page.dart';
import 'widgets/sources_page.dart';
import 'widgets/ai_config_page.dart';

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
  final TextEditingController _aiEndpointController = TextEditingController(
    text: 'http://localhost:11434',
  );
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
        if (status == 'success' ||
            response.toLowerCase().contains('ok') ||
            response.toLowerCase().contains('success')) {
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
                    const IntroPage(),
                    EnvCheckPage(
                      envData: _envData,
                      isCheckingEnv: _isCheckingEnv,
                      isBootstrapping: _isBootstrapping,
                      bootstrapLogs: _bootstrapLogs,
                      onCheckEnvironment: _checkEnvironment,
                      onStartBootstrap: _startBootstrap,
                      terminalScrollController: _terminalScrollController,
                    ),
                    SourcesPage(
                      enableAur: _enableAur,
                      onAurChanged: (val) {
                        setState(() {
                          _enableAur = val;
                        });
                      },
                    ),
                    AiConfigPage(
                      enableAI: _enableAI,
                      onEnableAIChanged: (val) {
                        setState(() {
                          _enableAI = val;
                        });
                      },
                      aiProvider: _aiProvider,
                      onAiProviderChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _aiProvider = val;
                            if (val == 'ollama') {
                              _aiEndpointController.text =
                                  'http://localhost:11434';
                            } else {
                              _aiEndpointController.text =
                                  'https://api.openai.com/v1';
                            }
                          });
                        }
                      },
                      aiEndpointController: _aiEndpointController,
                      aiApiKeyController: _aiApiKeyController,
                      isTestingAI: _isTestingAI,
                      aiTestResult: _aiTestResult,
                      aiTestSuccess: _aiTestSuccess,
                      onTestAIConnection: _testAIConnection,
                    ),
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
              _currentPage < 3
                  ? Icons.arrow_forward_rounded
                  : Icons.login_rounded,
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
