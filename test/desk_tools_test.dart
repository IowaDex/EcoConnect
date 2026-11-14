import 'package:eco_connect/core/widgets/eco_card.dart';
import 'package:eco_connect/features/cityhall/widgets/desk_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('desk tools', () {
    testWidgets('keeps all twelve shortcuts and the count in the header',
        (tester) async {
      await tester.pumpWidget(_wrap(const DeskTools(pendingSignatures: 2)));

      expect(find.text('Desk tools'), findsOneWidget);
      expect(find.text('12 shortcuts'), findsOneWidget);
      expect(find.byType(EcoCard), findsNWidgets(12));

      for (final label in const [
        'Complaints',
        'Resident requests',
        'Manuals',
        'Manual requests',
        'Delay reports',
        'Incidents',
        'Wave 2',
        'Memos',
        'Email log',
        'Accounts',
        'Fleet',
        'Signatures',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'missing $label');
      }
    });

    testWidgets('lays out two columns on a phone and more on wider screens',
        (tester) async {
      for (final (width, columns) in const [
        (320.0, 2),
        (360.0, 2),
        (412.0, 2),
        (600.0, 3),
        (800.0, 4),
        (980.0, 5),
      ]) {
        await _pumpAtWidth(tester, width);

        final lefts = <double>{};
        for (var i = 0; i < 12; i++) {
          lefts.add(tester.getTopLeft(find.byType(EcoCard).at(i)).dx);
        }
        expect(lefts.length, columns, reason: 'at ${width}px wide');

        // Every card sits inside the viewport: nothing is clipped off-screen.
        for (var i = 0; i < 12; i++) {
          final rect = tester.getRect(find.byType(EcoCard).at(i));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
        }
      }
    });

    testWidgets('never scrolls sideways and reports no overflow',
        (tester) async {
      await _pumpAtWidth(tester, 320);

      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.physics, isA<NeverScrollableScrollPhysics>());

      final scrollables = tester
          .widgetList<Scrollable>(find.byType(Scrollable))
          .where((s) => s.axisDirection == AxisDirection.right ||
              s.axisDirection == AxisDirection.left);
      expect(scrollables, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every shortcut keeps its route', (tester) async {
      final routes = <String>[];
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: SingleChildScrollView(
                child: DeskTools(pendingSignatures: 0),
              ),
            ),
          ),
          GoRoute(
            path: '/complaints',
            builder: (context, state) => _destination(routes, state),
          ),
          GoRoute(
            path: '/cityhall-requests',
            builder: (context, state) => _destination(routes, state),
          ),
          GoRoute(
            path: '/cityhall/signatures',
            builder: (context, state) => _destination(routes, state),
          ),
          GoRoute(
            path: '/fleet',
            builder: (context, state) => _destination(routes, state),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      for (final (label, route) in const [
        ('Complaints', '/complaints'),
        ('Resident requests', '/cityhall-requests'),
        ('Signatures', '/cityhall/signatures'),
        ('Fleet', '/fleet'),
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(routes.last, route);

        router.pop();
        await tester.pumpAndSettle();
      }
    });
  });
}

Widget _destination(List<String> routes, GoRouterState state) {
  routes.add(state.uri.path);
  return const Scaffold(body: Text('destination'));
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

Future<void> _pumpAtWidth(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(const DeskTools(pendingSignatures: 0)));
  await tester.pump();
}
