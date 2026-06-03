import "package:frontend/backend/repositories/package_repository.dart";
import "package:provider/provider.dart";
import "package:frontend/features/explore/presentation/pages/details_page.dart";
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/core/network/github_client.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/widgets/app_source_tag.dart';
import 'package:frontend/widgets/github_star_badge.dart';

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
        _apps = results.map((json) => AppPackage.fromJson(json)).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final client = context.read<GitHubClient>();

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: scheme.primary),
      );
    }

    return RefreshIndicator(
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
    );
  }
}
