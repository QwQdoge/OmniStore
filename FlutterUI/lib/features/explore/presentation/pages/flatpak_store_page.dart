import "package:frontend/data/repositories/package_repository.dart";
import "package:provider/provider.dart";
import "package:frontend/features/explore/presentation/pages/details_page.dart";
import 'package:flutter/material.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/explore/presentation/widgets/flatpak_app_list.dart';

class FlatpakStorePage extends StatefulWidget {
  const FlatpakStorePage({super.key});

  @override
  State<FlatpakStorePage> createState() => _FlatpakStorePageState();
}

class _FlatpakStorePageState extends State<FlatpakStorePage> {
  List<AppPackage> _apps = [];
  bool _isLoading = true;
  AppPackage? _selectedApp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final packageRepo = context.read<PackageRepository>();
    final results = await packageRepo.searchPackages("source:flatpak");
    if (!mounted) return;
    setState(() {
      _apps = results;
      _isLoading = false;
      if (results.isNotEmpty && _selectedApp == null) {
        _selectedApp = results.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 900;

    Widget bodyContent = FlatpakAppList(
      apps: _apps,
      isLoading: _isLoading,
      isDesktop: isDesktop,
      selectedApp: _selectedApp,
      onRetry: _refresh,
      onAppSelected: (app) {
        setState(() {
          _selectedApp = app;
        });
      },
    );

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            Expanded(flex: 4, child: bodyContent),
            const VerticalDivider(width: 1),
            Expanded(
              flex: 6,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.fastOutSlowIn,
                child: _selectedApp == null
                    ? Center(
                        key: const ValueKey('no_selection'),
                        child: Text(
                          AppLocalizations.of(context)!.noResults,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : AppDetailsPage(
                        app: _selectedApp!,
                        isEmbedded: true,
                        key: ValueKey(_selectedApp!.id),
                      ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(backgroundColor: Colors.transparent, body: bodyContent);
    }
  }
}
