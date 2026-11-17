import 'package:eco_connect/core/models/waste_category.dart';
import 'package:eco_connect/features/requests/models/collection_request.dart';
import 'package:flutter_test/flutter_test.dart';

CollectionRequest _request({
  int wave = 2,
  RequestStatus status = RequestStatus.pending,
  String cityHallStatus = 'none',
}) {
  return CollectionRequest(
    id: 'r1',
    requesterId: 'u1',
    requesterName: 'Resident',
    kind: RequestKind.resident,
    title: 'Uncollected garbage',
    description: 'Missed pickup',
    category: WasteCategory.residual,
    estimatedQuantity: '2 sacks',
    location: 'Purok 3',
    preferredDate: DateTime(2026, 11, 18),
    wave: wave,
    status: status,
    cityHallStatus: cityHallStatus,
  );
}

void main() {
  group('wave 2 stage wording', () {
    test('follows the barangay review before City Hall', () {
      expect(_request().wave2StageLabel, 'Submitted');
      expect(
        _request(status: RequestStatus.underReview).wave2StageLabel,
        'Under barangay review',
      );
      expect(
        _request(status: RequestStatus.approved).wave2StageLabel,
        'Verified by barangay',
      );
    });

    test('City Hall decision wins over the collection status', () {
      expect(
        _request(
          status: RequestStatus.underReview,
          cityHallStatus: 'pending',
        ).wave2StageLabel,
        'Forwarded to City Hall',
      );
      expect(
        _request(
          status: RequestStatus.approved,
          cityHallStatus: 'approved',
        ).wave2StageLabel,
        'Approved by City Hall',
      );
      expect(
        _request(cityHallStatus: 'rejected').wave2StageLabel,
        'Declined by City Hall',
      );
    });

    test('never leaks a raw field value', () {
      final labels = <String>{
        for (final status in RequestStatus.values)
          _request(status: status).wave2StageLabel,
        for (final cityHall in ['none', 'pending', 'approved', 'rejected'])
          _request(cityHallStatus: cityHall).wave2StageLabel,
      };
      expect(labels.any((label) => label.contains('_')), isFalse);
      expect(labels.any((label) => label == 'none'), isFalse);
    });
  });
}
