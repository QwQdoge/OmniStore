import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../services/app_package.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_source_tag.dart';
import 'app_details_page.dart';

class GitHubStorePage extends StatefulWidget {
  const GitHubStorePage({super.key});

  @override
  State<GitHubStorePage> createState() => _GitHubStorePageState();
}

class _GitHubStorePageState extends State<GitHubStorePage> {
  List<AppPackage> _trending = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTrending();
  }

  Future<void> _fetchTrending() async {
    setState(() => _isLoading = true);
    // Since we merged recommendations, we can just use the search logic with a high star filter or a specific recommendations call
    final recs = await BackendService.instance.getRecommendations();
    if (mounted) {
      setState(() {
        // Filter for GitHub sources if possible, or just use what backend provided as 'featured'
        _trending = recs['featured']?.where((a) => a.primarySource == 'GitHub').toList() ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Row(
            children: [
              const Icon(Icons.code_rounded, size: 32),
              const SizedBox(width: 16),
              Text(
                "GitHub Store",
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -1),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            "Discover software directly from open source repositories",
            style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _trending.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _trending.length,
                  itemBuilder: (context, index) => _buildRepoCard(_trending[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("No trending repositories found"),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              BackendService.navigationIndex.value = 2;
              BackendService.pendingSearchQuery.value = "stars:>1000";
            },
            icon: const Icon(Icons.search),
            label: const Text("Explore GitHub"),
          ),
        ],
      ),
    );
  }

  Widget _buildRepoCard(AppPackage app) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: app.icon != null
            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(app.icon!, fit: BoxFit.cover))
            : const Icon(Icons.code_rounded),
        ),
        title: Text(app.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(app.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            const AppSourceTag(source: "GitHub", mode: AppSourceTagMode.source),
          ],
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => AppDetailsPage(app: app)));
        },
      ),
    );
  }
}
