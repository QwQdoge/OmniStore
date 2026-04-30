import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../services/l10n_service.dart';

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
  final BackendService _backend = BackendService();

  @override
  void initState() {
    super.initState();
    _checkEnv();
  }

  Future<void> _checkEnv() async {
    final status = await _backend.checkEnv();
    setState(() {
      _envStatus = status;
      _hasFatal = status.values.any((e) => e['status'] == 'fatal');
      _hasWarning = status.values.any((e) => e['status'] == 'warning');
    });
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
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _finishSetup();
    }
  }

  Future<void> _finishSetup() async {
    final config = await _backend.loadConfig();
    config['first_run'] = false;
    config['search'] ??= {};
    config['search']['sources'] ??= {};
    config['search']['sources']['aur'] = _enableAUR;
    await _backend.saveConfig(config);
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Container(
          width: 600,
          height: 500,
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
                    child: _buildCurrentStep(),
                  ),
                ),
              ),
              _buildFeedbackArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeStep();
      case 1:
        return _buildEnvCheckStep();
      case 2:
        return _buildSourceStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWelcomeStep() {
    return Column(
      key: const ValueKey(0),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shop_two_rounded, size: 80, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          L10nService.s('welcome_title'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            L10nService.s('welcome_subtitle'),
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
          child: Text(L10nService.s('get_started'), style: const TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildEnvCheckStep() {
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
                    Text(L10nService.s('env_check_title'), style: Theme.of(context).textTheme.titleLarge),
                    Text(L10nService.s('env_check_subtitle'), style: Theme.of(context).textTheme.bodyMedium),
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
                ? L10nService.s('env_fatal_desc')
                : (_hasWarning ? L10nService.s('env_warning_desc') : L10nService.s('env_ok_desc')),
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
                  TextButton(onPressed: _nextStep, child: Text(L10nService.s('continue_anyway'))),
                const SizedBox(width: 8),
                if (_hasWarning && !_hasFatal)
                  FilledButton(onPressed: _runBootstrap, child: Text(L10nService.s('fix_problems')))
                else if (!_hasFatal)
                  FilledButton(onPressed: _nextStep, child: Text(L10nService.s('confirm'))),
              ],
            ),
          if (_isBootstrapping)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(L10nService.s('bootstrap_note'), style: Theme.of(context).textTheme.labelSmall),
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

  Widget _buildFeedbackArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Text(
        L10nService.s('feedback_desc'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSourceStep() {
    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(L10nService.s('source_config_title'), style: Theme.of(context).textTheme.titleLarge),
          Text(L10nService.s('source_config_subtitle'), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(L10nService.s('enable_aur')),
                    subtitle: Text(L10nService.s('yay_desc')),
                    value: _enableAUR,
                    onChanged: (v) => setState(() => _enableAUR = v),
                  ),
                  if (_enableAUR)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        L10nService.s('aur_warning'),
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
                onPressed: _finishSetup,
                child: Text(L10nService.s('enter_store')),
              ),
            ],
          )
        ],
      ),
    );
  }
}
