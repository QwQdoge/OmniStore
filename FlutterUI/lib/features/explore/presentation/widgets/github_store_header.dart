import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // GitHub Icon Container with MD3 Surface Token
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: CachedNetworkImage(
                  imageUrl:
                      "https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png",
                  width: 32,
                  height: 32,
                  memCacheWidth: 64,
                  memCacheHeight: 64,
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
                      l10n.githubStore,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      l10n.githubStoreSubtitle,
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
          // Integrated Search Bar with MD3 12dp Shape Token
          SearchBar(
            controller: searchController,
            hintText: l10n.searchGithubHint,
            leading: const Icon(Icons.search_rounded),
            trailing: [
              if (isSearching)
                IconButton(
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.clear_rounded),
                  tooltip: l10n.clearSearch,
                ),
            ],
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(
              scheme.surfaceContainerHigh.withValues(alpha: 0.7),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
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
