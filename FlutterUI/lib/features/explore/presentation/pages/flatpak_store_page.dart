import "package:frontend/data/repositories/package_repository.dart";
import "package:provider/provider.dart";
import "package:frontend/features/explore/presentation/pages/details_page.dart";
import 'package:flutter/material.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/explore/presentation/widgets/flatpak_app_list.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

class FlatpakStorePage extends StatefulWidget {
  const FlatpakStorePage({super.key});

  @override
  State<FlatpakStorePage> createState() => _FlatpakStorePageState();
}

class _FlatpakStorePageState extends State<FlatpakStorePage> {
  List<AppPackage> _apps = [];
  bool _isLoading = true;
  String? _loadError;
  AppPackage? _selectedApp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final packageRepo = context.read<PackageRepository>();
    try {
      final results = await packageRepo.searchPackages(
        "source:flatpak",
        throwOnError: true,
      );
      if (!mounted) return;
      setState(() {
        _apps = results;
        _loadError = null;
        _isLoading = false;
        if (results.isNotEmpty && _selectedApp == null) {
          _selectedApp = results.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError =
            "Could not load Flatpak apps. Check Flathub/network access and try again.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ⚡ Bolt: Use a self-contained responsive layout builder that caches its child
    // to isolate MediaQuery changes. On parent state updates, didUpdateWidget clears the cache.
    // On resize, it only rebuilds the subtree if the 900px desktop threshold is actually crossed.
    return ResponsiveLayoutBuilder(
      builder: (context, isDesktop) {
        Widget bodyContent = FlatpakAppList(
          apps: _apps,
          isLoading: _isLoading,
          isDesktop: isDesktop,
          selectedApp: _selectedApp,
          loadError: _loadError,
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
                  child: SmoothSizeSwitcher(
                    alignment: Alignment.topCenter,
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
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: bodyContent,
          );
        }
      },
    );
  }
}

/// A self-contained widget that caches its built child to isolate MediaQuery rebuilding.
class ResponsiveLayoutBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool isDesktop) builder;

  const ResponsiveLayoutBuilder({super.key, required this.builder});

  @override
  State<ResponsiveLayoutBuilder> createState() => _ResponsiveLayoutBuilderState();
}

class _ResponsiveLayoutBuilderState extends State<ResponsiveLayoutBuilder> {
  bool? _lastIsDesktop;
  Widget? _cachedChild;

  @override
  void didUpdateWidget(covariant ResponsiveLayoutBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent state changed (e.g. apps loaded, details changed). Clear cache to rebuild.
    _cachedChild = null;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 900;

    if (_cachedChild == null || _lastIsDesktop != isDesktop) {
      _lastIsDesktop = isDesktop;
      _cachedChild = widget.builder(context, isDesktop);
    }

    return _cachedChild!;
  }
}
