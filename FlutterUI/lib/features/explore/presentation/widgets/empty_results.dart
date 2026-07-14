import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/category_service.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';
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


  @override
  Widget build(BuildContext context) {
    final _categories = CategoryService.getCategories(context);
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: widget.l10n.noResults,
      child: Column(
        children: [
          Text(
            widget.l10n.categories,
            style: OmnistoreTheme.standardHeader(context),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
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
                      borderRadius: BorderRadius.circular(24),
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
