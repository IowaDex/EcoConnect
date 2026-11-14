import 'package:eco_connect/features/announcements/models/announcement.dart';
import 'package:eco_connect/features/requests/models/collection_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uncollected-garbage reports round-trip as their own kind', () {
    expect(RequestKindX.fromName('uncollected'), RequestKind.uncollected);
    expect(RequestKind.uncollected.name, 'uncollected');
    expect(RequestKind.uncollected.label, 'Uncollected garbage (Wave 2)');
    expect(RequestKindX.fromName('special'), RequestKind.special);
    expect(RequestKindX.fromName(null), RequestKind.resident);
    expect(RequestKindX.fromName('something-else'), RequestKind.resident);
  });

  test('delay announcements have their own category', () {
    expect(AnnouncementCategoryX.fromName('delay'), AnnouncementCategory.delay);
    expect(AnnouncementCategory.delay.label, 'Collection delay');
    expect(AnnouncementCategory.delay.shortLabel, 'Delay');
  });
}
