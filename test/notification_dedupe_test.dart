import 'package:eco_connect/features/notifications/models/app_notification.dart';
import 'package:eco_connect/features/notifications/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification _note({
  required String id,
  String title = 'Trip ticket for signature',
  String body = 'Dan submitted a trip ticket.',
  DateTime? createdAt,
  String userId = 'staff',
}) =>
    AppNotification(
      id: id,
      userId: userId,
      title: title,
      body: body,
      type: AppNotificationType.route,
      createdAt: createdAt,
    );

void main() {
  test('identical rows are collapsed to the newest copy', () {
    final newest = DateTime(2026, 11, 17, 10);
    final older = DateTime(2026, 11, 17, 9);
    final items = [
      _note(id: 'a', createdAt: newest),
      _note(id: 'b', createdAt: older),
      _note(id: 'c', title: 'Different', createdAt: older),
    ];

    final collapsed = NotificationService.collapseDuplicates(items);

    expect(collapsed.map((n) => n.id), ['a', 'c']);
  });

  test('a fresh server timestamp sorts above older rows', () {
    final items = [
      _note(id: 'old', createdAt: DateTime(2026, 11, 16)),
      _note(id: 'pending', createdAt: null),
    ]..sort(NotificationService.newestFirst);

    expect(items.first.id, 'pending');
  });
}
