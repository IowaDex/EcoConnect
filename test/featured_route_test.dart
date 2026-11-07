import 'package:eco_connect/features/route/models/collection_route.dart';
import 'package:eco_connect/features/route/services/route_service.dart';
import 'package:flutter_test/flutter_test.dart';

CollectionRoute _route(String id, {required Duration seenAgo}) =>
    CollectionRoute(
      driverId: id,
      driverName: id,
      status: RouteStatus.inTransit,
      lastSeenAt: DateTime.now().subtract(seenAgo),
    );

void main() {
  group('RouteService.pickFeaturedRoute', () {
    test('returns null when nobody is running', () {
      expect(RouteService.pickFeaturedRoute(const []), isNull);
    });

    test('prefers a reporting driver over one whose app went silent', () {
      final silent = _route('silent', seenAgo: const Duration(minutes: 30));
      final live = _route('live', seenAgo: const Duration(seconds: 10));

      expect(RouteService.pickFeaturedRoute([silent, live])!.driverId, 'live');
    });

    test('among live drivers the most recently seen wins', () {
      final older = _route('older', seenAgo: const Duration(minutes: 2));
      final newer = _route('newer', seenAgo: const Duration(seconds: 5));

      expect(RouteService.pickFeaturedRoute([older, newer])!.driverId, 'newer');
    });

    test('falls back to a stale run rather than showing nothing', () {
      final silent = _route('silent', seenAgo: const Duration(minutes: 30));

      expect(RouteService.pickFeaturedRoute([silent])!.driverId, 'silent');
    });
  });
}
