import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/category_service.dart';
import 'package:frontend/core/widgets/empty_state.dart';

class EmptyResults extends StatefulWidget {
  final AppLocalizations l10n;
  final TextEditingController searchController;
  final Function(String) performSearch;

  const EmptyResults({
    super.key,
    required this.l10n,
    required this.searchController,
    required this.performSearch,
  });

  @override
  State<EmptyResults> createState() => _EmptyResultsState();
}

class _EmptyResultsState extends State<EmptyResults> {
  // ⚡ Bolt: Memoize categories to avoid redundant allocations and L10n lookups on every build
  List<CategoryItem> _categories = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _categories = CategoryService.getCategories(context);
  }

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: widget.l10n.noResults,
      child: Column(
        children: [
          Text(
            widget.l10n.categories,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _categories
                .map(
                  (cat) => ActionChip(
                    onPressed: () {
                      widget.searchController.text =
                          '/${cat.id.toLowerCase()}';
                      widget.performSearch(widget.searchController.text);
                    },
                    label: Text(cat.name),
                    avatar: Icon(cat.icon, size: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
