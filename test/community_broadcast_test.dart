import 'package:eco_connect/features/community/models/community_post.dart';
import 'package:eco_connect/features/driver/services/driver_broadcast_service.dart';
import 'package:eco_connect/features/location/services/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('truck proximity rule', () {
    test('alerts arrival inside the arrived radius', () {
      expect(
        DriverBroadcastService.stageFor(metres: 90, previous: null),
        BroadcastStage.arrived,
      );
    });

    test('alerts approaching inside the approach radius', () {
      expect(
        DriverBroadcastService.stageFor(metres: 480, previous: null),
        BroadcastStage.approaching,
      );
    });

    test('stays quiet while far away and never seen', () {
      expect(
        DriverBroadcastService.stageFor(metres: 4200, previous: null),
        isNull,
      );
    });

    test('reports a pass only after moving well away', () {
      expect(
        DriverBroadcastService.stageFor(metres: 1400, previous: 500),
        BroadcastStage.passed,
      );
      expect(
        DriverBroadcastService.stageFor(metres: 900, previous: 500),
        isNull,
      );
    });

    test('the nearest band wins when both could apply', () {
      expect(
        DriverBroadcastService.stageFor(metres: 20, previous: 400),
        BroadcastStage.arrived,
      );
    });
  });

  group('community posts', () {
    test('parses likes and comments from a Firestore document', () {
      final post = CommunityPost.fromDoc('p1', {
        'authorId': 'u1',
        'authorName': 'Maria',
        'authorRole': 'user',
        'body': 'Collected our street today',
        'likedBy': ['u2', 'u3'],
        'comments': [
          {
            'id': 'c1',
            'authorId': 'u2',
            'authorName': 'Jose',
            'body': 'Thanks for the update!',
          },
        ],
      });

      expect(post.authorName, 'Maria');
      expect(post.isStaffPost, isFalse);
      expect(post.likeCount, 2);
      expect(post.commentCount, 1);
      expect(post.comments.first.authorName, 'Jose');
      expect(post.likedByUser('u2'), isTrue);
      expect(post.likedByUser('u9'), isFalse);
    });

    test('marks staff posts and tolerates missing fields', () {
      final post = CommunityPost.fromDoc('p2', {
        'authorRole': 'admin',
        'authorName': 'Barangay',
      });

      expect(post.isStaffPost, isTrue);
      expect(post.body, isEmpty);
      expect(post.likeCount, 0);
      expect(post.commentCount, 0);
    });
  });

  group('geocode results', () {
    test('shortens long display names to two parts', () {
      const result = GeocodeResult(
        displayName: 'Barangay San Isidro, Quezon City, Metro Manila, '
            'Philippines',
        point: LatLng(14.6, 121.0),
      );
      expect(result.shortName, 'Barangay San Isidro, Quezon City');
    });

    test('keeps short names intact', () {
      const result = GeocodeResult(
        displayName: 'San Isidro',
        point: LatLng(14.6, 121.0),
      );
      expect(result.shortName, 'San Isidro');
    });
  });
}
