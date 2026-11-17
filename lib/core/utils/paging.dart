/// Page arithmetic shared by every list screen.
///
/// Keeping this pure makes the "search/filter reset the page" behaviour easy
/// to test without a widget tree.
library;

/// Number of pages needed for [total] records. Always at least one page so the
/// UI can show "1–0 of 0" without a special case.
int pageCount(int total, int pageSize) {
  if (pageSize <= 0) return 1;
  if (total <= 0) return 1;
  return (total + pageSize - 1) ~/ pageSize;
}

/// Clamps a page index after a filter shrinks the result set.
int clampPage(int page, int total, int pageSize) {
  final last = pageCount(total, pageSize) - 1;
  if (page < 0) return 0;
  if (page > last) return last;
  return page;
}

/// The slice of [items] visible on [page].
List<T> pageSlice<T>(List<T> items, int page, int pageSize) {
  if (pageSize <= 0 || items.isEmpty) return <T>[];
  final safe = clampPage(page, items.length, pageSize);
  final start = safe * pageSize;
  if (start >= items.length) return <T>[];
  final end = (start + pageSize).clamp(0, items.length);
  return items.sublist(start, end);
}

/// "1–10 of 42" for the pagination footer.
String pageRangeLabel(int page, int pageSize, int total) {
  if (total <= 0) return '0 records';
  final safe = clampPage(page, total, pageSize);
  final start = safe * pageSize + 1;
  final end = (start + pageSize - 1).clamp(0, total);
  return '$start–$end of $total';
}
