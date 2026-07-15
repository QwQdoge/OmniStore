import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class GitHubStoreHeader extends StatelessWidget {
  final TextEditingController searchController;
  final bool isSearching;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;

  const GitHubStoreHeader({
    super.key,
    required this.searchController,
    required this.isSearching,
    required this.onSearchSubmitted,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [scheme.surfaceContainerHigh, scheme.surfaceContainerLowest]
              : [scheme.surfaceContainerLowest, scheme.surfaceContainerLow],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Glassmorphic GitHub Icon Container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: CachedNetworkImage(
                  imageUrl: "https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png",
                  width: 32,
                  height: 32,
                  color: isDark ? Colors.white : Colors.black87,
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.code_rounded, size: 32),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "GitHub App Store",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      "Discover and download apps directly from GitHub releases",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Premium Integrated Search Bar
          SearchBar(
            controller: searchController,
            hintText: "Search GitHub repositories...",
            leading: const Icon(Icons.search_rounded),
            trailing: [
              if (isSearching)
                IconButton(
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.clear_rounded),
                  tooltip: 'Clear search',
                ),
            ],
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(
              scheme.surfaceContainerHigh.withValues(alpha: 0.7),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            onSubmitted: onSearchSubmitted,
          ),
        ],
      ),
    );
  }
}
