import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/layout/widgets/route_sidebar.dart';

void main() {
  testWidgets('filters real destinations, preserves identity and blocks disabled routes', (tester) async {
    String? activated;
    const routes = [
      SidebarRoute(id: 'network', title: 'Network', subtitle: 'Wi-Fi', icon: Icons.wifi),
      SidebarRoute(id: 'privacy', title: 'Privacy', icon: Icons.security),
      SidebarRoute(id: 'disabled', title: 'Disabled', icon: Icons.block, enabled: false),
    ];
    Future<void> show(List<SidebarRoute> items) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 280,
        child: RouteSidebar(routes: items, selectedRoute: 'privacy',
          searchLabel: 'Search destinations', emptyLabel: 'No matching destinations',
          onSelected: (id) => activated = id)))));
      await tester.pumpAndSettle();
    }
    await show(routes);
    await tester.tap(find.text('Disabled'));
    expect(activated, isNull);
    await tester.enterText(find.byType(TextField), 'wi-fi');
    await tester.pumpAndSettle();
    expect(find.text('Privacy'), findsNothing);
    await tester.tap(find.text('Network'));
    expect(activated, 'network');
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No matching destinations'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await show(routes.reversed.toList());
    await tester.tap(find.text('Privacy'));
    expect(activated, 'privacy');
    expect(tester.takeException(), isNull);
  });

  testWidgets('long routes work at large text scale with reduced motion', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2), disableAnimations: true),
      child: Scaffold(body: SizedBox(width: 280, child: RouteSidebar(
        routes: [for (var i = 0; i < 30; i++) SidebarRoute(id: '$i',
          title: 'Destination $i', subtitle: 'Supporting information', icon: Icons.home)],
        selectedRoute: '29', searchLabel: 'Search', emptyLabel: 'No results', onSelected: (_) {},
      ))))));
    await tester.pumpAndSettle();
    expect(find.text('Destination 29').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
