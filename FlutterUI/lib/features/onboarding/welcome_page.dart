import "package:frontend/data/repositories/config_repository.dart";
import "package:provider/provider.dart";
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';

class WelcomePage extends StatefulWidget {
  final VoidCallback onFinish;
  const WelcomePage({super.key, required this.onFinish});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (idx) => setState(() => _currentPage = idx),
        children: [_buildIntroPage(l10n), _buildSetupPage(l10n)],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentPage > 0)
              TextButton(
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease,
                ),
                child: Text(l10n.back),
              ),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                if (_currentPage < 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease,
                  );
                } else {
                  final configRepo = context.read<ConfigRepository>();
                  final config = await configRepo.loadConfig();
                  config['first_run'] = false;
                  await configRepo.saveConfig(config);

                  if (!mounted) return;
                  widget.onFinish();
                }
              },
              child: Text(_currentPage < 1 ? l10n.next : l10n.getStarted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroPage(AppLocalizations l10n) {
    return Center(
      child: Text(
        l10n.welcomeTitle,
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildSetupPage(AppLocalizations l10n) {
    return Center(child: Text(l10n.welcomeSubtitle));
  }
}
