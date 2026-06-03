import "package:frontend/backend/repositories/package_repository.dart";
import "package:provider/provider.dart";
import "details_page.dart";
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/widgets/app_source_tag.dart';

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _apps.length,
                itemBuilder: (context, index) {
                  final app = _apps[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: app.icon != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: app.icon!,
                                width: 40,
                                height: 40,
                                errorWidget: (c, e, s) =>
                                    const Icon(Icons.code_rounded),
                              ),
                            )
                          : const Icon(Icons.code_rounded, size: 40),
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
}
