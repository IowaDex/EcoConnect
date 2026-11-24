import 'package:eco_connect/core/theme/app_theme.dart';
import 'package:eco_connect/features/location/providers/location_provider.dart';
import 'package:eco_connect/features/location/repositories/location_repository.dart';
import 'package:eco_connect/features/location/services/location_service.dart';
import 'package:eco_connect/features/location/widgets/location_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeRepository extends Fake implements LocationRepository {
  @override
  String? currentUserId = 'u1';

  @override
  Stream<String?> get userIdChanges => const Stream.empty();

  @override
  Future<int> pendingCount() async => 0;

  @override
  Future<int> syncPending() async => 0;
}

class _FakeService extends Fake implements LocationService {}

void main() {
  group('location controls', () {
    late LocationProvider provider;

    setUp(() {
      provider = LocationProvider(
        repository: _FakeRepository(),
        service: _FakeService(),
        connectivityChanges: const Stream.empty(),
      );
    });

    tearDown(() => provider.dispose());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ChangeNotifierProvider<LocationProvider>.value(
            value: provider,
            child: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(20),
                child: LocationControls(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('reads as off, with the switch left open', (tester) async {
      await pump(tester);

      expect(find.text('Real-time tracking'), findsOneWidget);
      expect(
        find.text('Turn on to record your location · only you can see it'),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a narrow phone still fits the label and the switch', (
      tester,
    ) async {
      await pump(tester);

      final card = tester.getRect(find.byType(LocationControls));
      expect(card.right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });
  });
}
