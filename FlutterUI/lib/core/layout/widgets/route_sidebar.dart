import 'package:flutter/material.dart';

class SidebarRoute {
  const SidebarRoute({
    required this.id,
    required this.title,
    required this.icon,
    this.subtitle = '',
    this.enabled = true,
  });
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
}

/// Search-first, connected destination rows shared by persistent and modal layouts.
class RouteSidebar extends StatefulWidget {
  const RouteSidebar({
    super.key,
    required this.routes,
    required this.selectedRoute,
    required this.onSelected,
    required this.searchLabel,
    required this.emptyLabel,
    this.autofocus = false,
    this.footer,
  });
  final List<SidebarRoute> routes;
  final String selectedRoute;
  final ValueChanged<String> onSelected;
  final String searchLabel;
  final String emptyLabel;
  final bool autofocus;
  final Widget? footer;
  @override
  State<RouteSidebar> createState() => _RouteSidebarState();
}

class _RouteSidebarState extends State<RouteSidebar> {
  final _keys = <String, GlobalKey>{};
  String _query = '';
  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(RouteSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRoute != widget.selectedRoute ||
        oldWidget.routes.length != widget.routes.length ||
        Iterable<int>.generate(
          widget.routes.length,
        ).any((i) => oldWidget.routes[i].id != widget.routes[i].id)) {
      _revealSelected();
    }
  }

  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _query.isNotEmpty) return;
      final selectedContext = _keys[widget.selectedRoute]?.currentContext;
      if (selectedContext != null) {
        Scrollable.ensureVisible(
          selectedContext,
          alignment: .5,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = widget.routes
        .where(
          (route) =>
              '${route.title} ${route.subtitle}'.toLowerCase().contains(_query),
        )
        .toList();
    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                autofocus: widget.autofocus,
                decoration: InputDecoration(
                  labelText: widget.searchLabel,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() => _query = value.trim().toLowerCase());
                  if (_query.isEmpty) _revealSelected();
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (rows.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            widget.emptyLabel,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (var i = 0; i < rows.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Semantics(
                            selected: rows[i].id == widget.selectedRoute,
                            child: Material(
                              key: _keys.putIfAbsent(rows[i].id, GlobalKey.new),
                              color: rows[i].id == widget.selectedRoute
                                  ? scheme.secondaryContainer
                                  : scheme.surfaceContainer,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(i == 0 ? 24 : 4),
                                bottom: Radius.circular(
                                  i == rows.length - 1 ? 24 : 4,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                enabled: rows[i].enabled,
                                selected: rows[i].id == widget.selectedRoute,
                                selectedColor: scheme.onSecondaryContainer,
                                leading: Icon(rows[i].icon),
                                title: Text(rows[i].title),
                                subtitle: rows[i].subtitle.isEmpty
                                    ? null
                                    : Text(rows[i].subtitle),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: rows[i].enabled
                                    ? () => widget.onSelected(rows[i].id)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.footer != null) widget.footer!,
            ],
          ),
        ),
      ),
    );
  }
}
