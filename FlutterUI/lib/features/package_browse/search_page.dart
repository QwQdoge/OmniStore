import "package:provider/provider.dart";
import "browse_controller.dart";
import "details_page.dart";
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/widgets/app_source_tag.dart';
import 'package:frontend/widgets/magic_pulse_icon.dart';
import 'package:frontend/widgets/ai_app_resolver.dart';
import 'package:frontend/features/settings/settings_controller.dart';

class SearchPage extends StatefulWidget {
  final bool autoFocus;
  const SearchPage({super.key, this.autoFocus = false});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showDiscovery = true;

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final browse = context.read<BrowseController>();
      if (browse.pendingSearchQuery != null) {
        _searchController.text = browse.pendingSearchQuery!;
        _performSearch(browse.pendingSearchQuery!);
        browse.pendingSearchQuery = null;
      }
    });
  }

  void _performSearch(String query) {
    if (query.length < 2) {
      setState(() => _showDiscovery = true);
      return;
    }
    setState(() => _showDiscovery = false);
    context.read<BrowseController>().search(query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final browse = context.watch<BrowseController>();
    final settings = context.watch<SettingsController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: SearchBar(
              controller: _searchController,
              focusNode: _focusNode,
              hintText: l10n.searchHint,
              onSubmitted: _performSearch,
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _showDiscovery = true);
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: _showDiscovery
                ? _buildDiscovery(l10n)
                : browse.isSearching
                ? const Center(child: CircularProgressIndicator())
                : _buildResults(browse, l10n, settings),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscovery(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.explore_rounded,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(l10n.explore, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildResults(
    BrowseController browse,
    AppLocalizations l10n,
    SettingsController settings,
  ) {
    if (browse.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(l10n.noResults, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: browse.searchResults.length,
      itemBuilder: (context, index) {
        final app = browse.searchResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Hero(
              tag: 'app-icon-${app.name}',
              child: app.icon != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: app.icon!,
                        width: 40,
                        height: 40,
                        errorWidget: (c, e, s) => const Icon(Icons.apps),
                      ),
                    )
                  : const Icon(Icons.apps, size: 40),
            ),
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
              MaterialPageRoute(builder: (context) => AppDetailsPage(app: app)),
            ),
          ),
        );
      },
    );
  }
}
