import 'package:flutter/material.dart';

class AdaptiveScaffold extends StatelessWidget {
  final Widget body;
  final Widget? sideBar;
  final Widget? bottomNav;
  final bool useSidebar;

  const AdaptiveScaffold({
    super.key,
    required this.body,
    this.sideBar,
    this.bottomNav,
    this.useSidebar = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop && useSidebar && sideBar != null) {
          return Scaffold(
            body: Row(
              children: [
                sideBar!,
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: !isDesktop && bottomNav != null
              ? bottomNav
              : null,
        );
      },
    );
  }
}
