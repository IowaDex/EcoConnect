import 'package:eco_connect/core/widgets/section_header.dart';
import 'package:eco_connect/features/dashboard/widgets/quick_action_grid.dart';
import 'package:eco_connect/features/dashboard/widgets/role_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('role hero', () {
    testWidgets('shows the eyebrow, name, purpose and animated counters', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const RoleHero(
            icon: Icons.account_balance_rounded,
            eyebrow: 'CITY HALL · DOCUMENT DESK',
            greeting: 'Good morning',
            title: 'Maria Santos',
            subtitle: 'Review and sign everything addressed to the DSQC.',
            chip: RoleChip(label: '2 awaiting', icon: Icons.draw_rounded),
            stats: [
              RoleStat(icon: Icons.draw_rounded, label: 'Awaiting', value: 2),
              RoleStat(icon: Icons.inbox_rounded, label: 'Received', value: 7),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CITY HALL · DOCUMENT DESK'), findsOneWidget);
      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('2 awaiting'), findsOneWidget);
      expect(find.text('AWAITING'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps a long name and purpose inside the card', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          const RoleHero(
            icon: Icons.person_rounded,
            eyebrow: 'RESIDENT · BATASAN HILLS',
            title: 'Maria Clara Santos-Dela Cruz the Third',
            subtitle:
                'Block 12, Lot 4, Villa Beatriz Subdivision, Batasan Hills, '
                'Quezon City, Metro Manila',
            stats: [
              RoleStat(
                icon: Icons.assignment_rounded,
                label: 'Open requests',
                value: 0,
              ),
              RoleStat(
                icon: Icons.report_rounded,
                label: 'Open complaints',
                value: 12,
              ),
              RoleStat(icon: Icons.inbox_rounded, label: 'Received', value: 3),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(RoleHero));
      expect(card.right, lessThanOrEqualTo(320));
    });
  });

  group('quick action grid', () {
    testWidgets('lays out two columns on a phone', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const QuickActionGrid(actions: _actions)));

      final lefts = <double>{
        for (var i = 0; i < _actions.length; i++)
          tester.getTopLeft(find.text(_actions[i].label)).dx,
      };
      expect(lefts.length, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens the route of the tile that was tapped', (tester) async {
      final routes = <String>[];
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: SingleChildScrollView(
                child: QuickActionGrid(actions: _actions),
              ),
            ),
          ),
          GoRoute(
            path: '/tracking',
            builder: (context, state) {
              routes.add(state.uri.path);
              return const Scaffold(body: Text('destination'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Track truck'));
      await tester.pumpAndSettle();
      expect(routes, ['/tracking']);
    });
  });

  group('section label', () {
    testWidgets('renders the action only when both label and callback exist', (
      tester,
    ) async {
      var tapped = 0;

      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              const SectionLabel('QUICK ACTIONS'),
              SectionLabel(
                'UPCOMING EVENTS',
                action: 'View all',
                onAction: () => tapped++,
              ),
            ],
          ),
        ),
      );

      expect(find.text('QUICK ACTIONS'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);

      await tester.tap(find.text('View all'));
      expect(tapped, 1);
    });
  });
}

const _actions = <QuickAction>[
  QuickAction(
    label: 'Track truck',
    icon: Icons.local_shipping_rounded,
    route: '/tracking',
  ),
  QuickAction(
    label: 'My requests',
    icon: Icons.fact_check_outlined,
    route: '/my-requests',
  ),
  QuickAction(
    label: 'Complaints',
    icon: Icons.report_outlined,
    route: '/my-complaints',
  ),
];

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
