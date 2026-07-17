import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/navigation_controller.dart';
import 'package:frontend/features/explore/presentation/controllers/browse_controller.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/category_service.dart';

class CategoryQuickAccess extends StatelessWidget {
  final List<CategoryItem> categories;
  final ScrollController scrollController;

  const CategoryQuickAccess({
    super.key,
    required this.categories,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 66,
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          child: ListView.builder(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            prototypeItem: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                label: 'Prototype',
                child: const ActionChip(
                  avatar: Icon(Icons.apps, size: 18),
                  label: Text('Prototype Category'),
                  onPressed: null,
                ),
              ),
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                label: AppLocalizations.of(context)!.categorySemantics(
                  categories[index].name,
                ),
                child: ActionChip(
                  avatar: Icon(categories[index].icon, size: 18),
                  label: Text(categories[index].name),
                  tooltip: categories[index].name,
                  onPressed: () {
                    final browse = context.read<BrowseController>();
                    browse.pendingSearchQuery =
                        '/${categories[index].id.toLowerCase()}';
                    context.read<NavigationController>().setIndex(2);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
