import 'package:eco_connect/features/memos/services/memo_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const memo = Memo(
    id: 'm1',
    kind: MemoKind.endorsement,
    subject: 'Route 4 truck reassignment',
    body: 'Please move the morning sweep to Zone 3 starting Monday.',
    fromName: 'Ramon Dela Cruz',
    fromRole: 'iswim',
    fromUid: 'uid-1',
    toChannel: 'cityHall',
    status: MemoStatus.acknowledged,
    acknowledgedByName: 'Marites Santos',
  );

  group('memo search', () {
    test('an empty query keeps every memo', () {
      expect(memoMatchesQuery(memo, ''), isTrue);
      expect(memoMatchesQuery(memo, '   '), isTrue);
    });

    test('matches the subject, the body and the sender', () {
      expect(memoMatchesQuery(memo, 'reassignment'), isTrue);
      expect(memoMatchesQuery(memo, 'zone 3'), isTrue);
      expect(memoMatchesQuery(memo, 'ramon'), isTrue);
    });

    test('matches the kind, the receiving desk and the signer', () {
      expect(memoMatchesQuery(memo, 'endorsement'), isTrue);
      expect(memoMatchesQuery(memo, 'city hall'), isTrue);
      expect(memoMatchesQuery(memo, 'santos'), isTrue);
    });

    test('is case-insensitive and trims the query', () {
      expect(memoMatchesQuery(memo, '  ROUTE 4  '), isTrue);
      expect(memoMatchesQuery(memo, 'MORNING'), isTrue);
    });

    test('rejects words the memo never contains', () {
      expect(memoMatchesQuery(memo, 'barangay hall annex'), isFalse);
      expect(memoMatchesQuery(memo, 'tuesday'), isFalse);
    });
  });
}
