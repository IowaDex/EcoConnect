import 'package:eco_connect/core/utils/paging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('page arithmetic', () {
    test('page count rounds up and never returns zero', () {
      expect(pageCount(0, 10), 1);
      expect(pageCount(1, 10), 1);
      expect(pageCount(10, 10), 1);
      expect(pageCount(11, 10), 2);
      expect(pageCount(42, 10), 5);
    });

    test('clamp keeps a page inside the result set', () {
      expect(clampPage(-3, 42, 10), 0);
      expect(clampPage(2, 42, 10), 2);
      expect(clampPage(99, 42, 10), 4);
      expect(clampPage(4, 0, 10), 0);
    });

    test('slice returns the records for the page', () {
      final items = List.generate(23, (i) => i);
      expect(pageSlice(items, 0, 10), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(pageSlice(items, 2, 10), [20, 21, 22]);
      expect(pageSlice(items, 99, 10), [20, 21, 22]);
      expect(pageSlice(<int>[], 0, 10), isEmpty);
    });

    test('range label describes the visible window', () {
      expect(pageRangeLabel(0, 10, 0), '0 records');
      expect(pageRangeLabel(0, 10, 42), '1–10 of 42');
      expect(pageRangeLabel(4, 10, 42), '41–42 of 42');
      expect(pageRangeLabel(9, 10, 42), '41–42 of 42');
    });

    test('filtering that shrinks the list resets to a valid page', () {
      // Search went from 42 matches to 3 while the user was on page 4.
      final page = clampPage(4, 3, 10);
      expect(page, 0);
      expect(pageSlice(List.generate(3, (i) => i), page, 10), [0, 1, 2]);
    });
  });
}
