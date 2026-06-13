import "package:frontend/data/repositories/package_repository.dart";
import "package:provider/provider.dart";
import "package:frontend/features/explore/presentation/pages/details_page.dart";
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/core/network/github_client.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/core/widgets/app_source_tag.dart';
import 'package:frontend/core/widgets/github_star_badge.dart';
import 'package:frontend/core/widgets/skeleton.dart';

class GitHubStorePage extends StatefulWidget {
  const GitHubStorePage({super.key});

  @override
  State<GitHubStorePage> createState() => _GitHubStorePageState();
}

class _GitHubStorePageState extends State<GitHubStorePage> {
  List<AppPackage> _apps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final packageRepo = context.read<PackageRepository>();
    final results = await packageRepo.searchPackages("source:github");
    if (mounted) {
      setState(() {
        _apps = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final client = context.read<GitHubClient>();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isLoading
          ? _buildSkeletonList(key: const ValueKey('loading'))
          : RefreshIndicator(
              key: const ValueKey('list'),
              onRefresh: _refresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _apps.length,
                itemBuilder: (context, index) {
                  final app = _apps[index];
                  final repoUrl = app.url ?? app.homepage;

                  return Card.filled(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: scheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                                    const Icon(Icons.code_rounded),
                              ),
                            )
                          : const Icon(Icons.code_rounded, size: 44),
                      title: Text(
                        app.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        app.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (GitHubClient.parseUrl(repoUrl) != null)
                            GitHubStarBadge(
                              client: client,
                              repositoryUrl: repoUrl,
                              compact: true,
                            ),
                          const SizedBox(width: 8),
                          AppSourceTag(
                            source: app.primarySource,
                            mode: AppSourceTagMode.source,
                          ),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AppDetailsPage(app: app),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
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
          ),
          child: const ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
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
