import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/backend_service.dart';

class WelcomePage extends StatefulWidget {
  final VoidCallback onFinish;
  const WelcomePage({super.key, required this.onFinish});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  int _currentStep = 0;
  bool _hasWarning = false;
  bool _hasFatal = false;
  Map<String, dynamic> _envStatus = {};
  bool _isBootstrapping = false;
  String _bootstrapLog = "";
  bool _enableAUR = true;

  // AI Onboarding State
  bool _enableAI = false;
  String _aiProvider = 'ollama';
  final TextEditingController _aiEndpoint = TextEditingController(text: 'http://localhost:11434');
  final TextEditingController _aiApiKey = TextEditingController();

  final BackendService _backend = BackendService.instance;

  @override
  void initState() {
    super.initState();
    _checkEnv();
  }

  @override
  void dispose() {
    _aiEndpoint.dispose();
    _aiApiKey.dispose();
    super.dispose();
  }

  Future<void> _checkEnv() async {
    try {
      final status = await _backend.checkEnv().timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _envStatus = status;
          _hasFatal = status.values.any((e) => e['status'] == 'fatal');
          _hasWarning = status.values.any((e) => e['status'] == 'warning');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasFatal = true;
          _envStatus = {
            "Backend": {"status": "fatal", "message": AppLocalizations.of(context)!.cannotConnectToBackend(e.toString())}
          };
        });
      }
    }
  }

  Future<void> _runBootstrap() async {
    setState(() {
      _isBootstrapping = true;
      _bootstrapLog = "";
    });

    _backend.bootstrap().listen((event) {
      String cleanLog = event;
      if (event.startsWith("[CALLBACK]")) {
        try {
          final data = jsonDecode(event.replaceFirst("[CALLBACK]", "").trim());
          cleanLog = data['log'] ?? data['message'] ?? event;
        } catch (_) {}
      }
      setState(() {
        _bootstrapLog += "$cleanLog\n";
      });
    }, onDone: () {
      _checkEnv().then((_) {
        setState(() => _isBootstrapping = false);
        if (!_hasWarning && !_hasFatal) {
          _nextStep();
        }
      });
    });
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _finishSetup();
    }
  }

  void _skipOnboarding() {
    _finishSetup();
  }

  Future<void> _finishSetup() async {
    // 强制先获取最新配置，确保不会覆盖掉之前的设置
    final config = await _backend.loadConfig();

    config['first_run'] = false;
    config['search'] ??= {};
    config['search']['sources'] ??= {};
    config['search']['sources']['aur'] = _enableAUR;

    config['ai'] ??= {};
    config['ai']['enabled'] = _enableAI;
    config['ai']['provider'] = _aiProvider;
    config['ai']['endpoint'] = _aiEndpoint.text;
    config['ai']['api_key'] = _aiApiKey.text;

    final success = await _backend.saveConfig(config);
    if (success) {
      debugPrint("Onboarding configuration saved successfully.");
      // 确保配置在内存中也是最新的
      await _backend.loadConfig();
      widget.onFinish();
    } else {
      debugPrint("Failed to save onboarding configuration.");
      // 如果保存失败，至少也尝试进入主界面，但最好能通知用户
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: Container(
          width: 600,
          height: 520,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    ...List.generate(4, (i) => Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i <= _currentStep ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
                    const SizedBox(width: 8),
                    TextButton(onPressed: _skipOnboarding, child: Text(l10n.skip)),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: animation.drive(
                            Tween(begin: const Offset(0, 0.1), end: Offset.zero)
                                .chain(CurveTween(curve: Curves.easeOutCubic)),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: _buildCurrentStep(l10n),
                  ),
                ),
              ),
              _buildFeedbackArea(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(AppLocalizations l10n) {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeStep(l10n);
      case 1:
        return _buildEnvCheckStep(l10n);
      case 2:
        return _buildSourceStep(l10n);
      case 3:
        return _buildAIStep(l10n);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWelcomeStep(AppLocalizations l10n) {
    return Column(
      key: const ValueKey(0),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shop_two_rounded, size: 80, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          l10n.welcomeTitle,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            l10n.welcomeSubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 48),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _nextStep,
          child: Text(l10n.getStarted, style: const TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildEnvCheckStep(AppLocalizations l10n) {
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Row(
            children: [
              _buildEnvIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.envCheckTitle, style: Theme.of(context).textTheme.titleLarge),
                    Text(l10n.envCheckSubtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: _envStatus.entries.map((e) => _buildStatusTile(e.key, e.value)).toList(),
                  ),
                ),
                if (_isBootstrapping)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Text(_bootstrapLog, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _hasFatal
                ? l10n.envFatalDesc
                : (_hasWarning ? l10n.envWarningDesc : l10n.envOkDesc),
            style: TextStyle(color: _hasFatal ? Colors.red : (_hasWarning ? Colors.orange : Colors.green)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_isBootstrapping)
            const LinearProgressIndicator()
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_hasFatal || _hasWarning)
                  TextButton(onPressed: _nextStep, child: Text(l10n.continueAnyway)),
                const SizedBox(width: 8),
                if (_hasWarning && !_hasFatal)
                  FilledButton(onPressed: _runBootstrap, child: Text(l10n.fixProblems))
                else if (!_hasFatal)
                  FilledButton(onPressed: _nextStep, child: Text(l10n.confirm)),
              ],
            ),
          if (_isBootstrapping)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(l10n.bootstrapNote, style: Theme.of(context).textTheme.labelSmall),
            ),
        ],
      ),
    );
  }

  Widget _buildEnvIcon() {
    if (_hasFatal) return const Icon(Icons.cancel_rounded, color: Colors.red, size: 48);
    if (_hasWarning) return const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48);
    return const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48);
  }

  Widget _buildStatusTile(String key, dynamic value) {
    final status = value['status'];
    final message = value['message'];
    IconData icon;
    Color color;

    if (status == 'ok') {
      icon = Icons.check_circle_outline;
      color = Colors.green;
    } else if (status == 'warning') {
      icon = Icons.priority_high_rounded; // Yellow exclamation
      color = Colors.orange;
    } else if (status == 'error') {
      icon = Icons.priority_high_rounded; // Red exclamation
      color = Colors.red;
    } else {
      icon = Icons.close_rounded; // Red cross
      color = Colors.red;
    }

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(message),
      dense: true,
    );
  }

  Widget _buildFeedbackArea(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Text(
        l10n.feedbackDesc,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildAIStep(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey(3),
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.aiAssistant, style: theme.textTheme.titleLarge),
          Text(l10n.aiAssistantDesc),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(l10n.aiEnabled),
                    value: _enableAI,
                    onChanged: (v) => setState(() => _enableAI = v),
                  ),
                  if (_enableAI) ...[
                    const Divider(),
                    ListTile(
                      title: Text(l10n.aiProvider),
                      trailing: DropdownButton<String>(
                        value: _aiProvider,
                        onChanged: (v) => setState(() => _aiProvider = v!),
                        items: [
                          DropdownMenuItem(value: 'ollama', child: Text(l10n.ollamaLocal)),
                          DropdownMenuItem(value: 'openai', child: Text(l10n.openaiCompatible)),
                        ],
                      ),
                    ),
                    TextField(
                      controller: _aiEndpoint,
                      decoration: InputDecoration(
                        labelText: l10n.aiEndpoint,
                        hintText: "http://localhost:11434",
                        helperText: l10n.aiEndpointHelper,
                      ),
                    ),
                    TextField(
                      controller: _aiApiKey,
                      decoration: InputDecoration(
                        labelText: l10n.aiApiKey,
                        helperText: l10n.aiApiKeyHelper,
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(l10n.howToGetApiKey),
                            content: Text(l10n.howToGetApiKeyDesc),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.gotIt)),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.help_outline_rounded, size: 16),
                      label: Text(l10n.help, style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.aiOllamaNote,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: _finishSetup,
                child: Text(l10n.enterStore),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSourceStep(AppLocalizations l10n) {
    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sourceConfigTitle, style: Theme.of(context).textTheme.titleLarge),
          Text(l10n.sourceConfigSubtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(l10n.enableAur),
                    subtitle: Text(l10n.yayDesc),
                    value: _enableAUR,
                    onChanged: (v) => setState(() => _enableAUR = v),
                  ),
                  if (_enableAUR)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        l10n.aurWarning,
                        style: const TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: _nextStep,
                child: Text(l10n.nextStep),
              ),
            ],
          )
        ],
      ),
    );
  }
}
