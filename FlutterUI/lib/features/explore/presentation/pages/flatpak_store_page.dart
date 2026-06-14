import "package:frontend/data/repositories/package_repository.dart";
import "package:provider/provider.dart";
import "package:frontend/features/explore/presentation/pages/details_page.dart";
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/core/widgets/app_source_tag.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_card.dart';

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
    if (mounted) {
      setState(() {
        _apps = results;
        _isLoading = false;
        if (results.isNotEmpty && _selectedApp == null) {
          _selectedApp = results.first;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    Widget buildListContent() {
      if (_apps.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.noResults,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Check your network connection and try again",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Retry"),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _apps.length,
        itemBuilder: (context, index) {
          final app = _apps[index];
          final isSelected = _selectedApp?.id == app.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              label: 'App: ${app.name}',
              button: true,
              child: AppCard(
                borderRadius: 16,
                color: isSelected && isDesktop
                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                onTap: () {
                  if (isDesktop) {
                    setState(() {
                      _selectedApp = app;
                    });
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AppDetailsPage(app: app),
                      ),
                    );
                  }
                },
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: app.icon != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: app.icon!,
                        width: 44,
                        height: 44,
                        memCacheWidth: 88,
                        memCacheHeight: 88,
                        errorWidget: (c, e, s) =>
                            const Icon(Icons.shopping_bag_rounded),
                      ),
                    )
                  : const Icon(Icons.shopping_bag_rounded, size: 44),
              title: Text(
                app.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                app.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: AppSourceTag(
                source: app.primarySource,
                mode: AppSourceTagMode.source,
              ),
            ),
          )));
        },
      );
    }

    Widget bodyContent = AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isLoading
          ? _buildSkeletonList(key: const ValueKey('loading'))
          : RefreshIndicator(
              key: const ValueKey('list'),
              onRefresh: _refresh,
              child: buildListContent(),
            ),
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
              child: _selectedApp == null
                  ? Center(
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
          ],
        ),
      );
    } else {
      return Scaffold(backgroundColor: Colors.transparent, body: bodyContent);
    }
  }

  Widget _buildSkeletonList({Key? key}) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      key: key,
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Card.filled(
          margin: const EdgeInsets.only(bottom: 12),
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          child: const ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Skeleton(width: 44, height: 44, borderRadius: 12),
            title: Skeleton(width: 120, height: 16),
            subtitle: Skeleton(width: double.infinity, height: 12),
            trailing: Skeleton(width: 60, height: 24, borderRadius: 6),
          ),
        );
      },
    );
  }
}
