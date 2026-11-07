const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int value) => value.toString().padLeft(2, '0');

/// Short date, e.g. "Nov 7, 2026".
String dateLabel(DateTime? date) {
  if (date == null) return '—';
  return '${_months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Date and time, e.g. "Nov 7 · 2:30 PM".
String dateTimeLabel(DateTime? date) {
  if (date == null) return '—';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = _two(date.minute);
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '${_months[date.month - 1]} ${date.day} · $hour:$minute $suffix';
}

/// Time only, e.g. "2:30 PM".
String timeLabel(DateTime? date) {
  if (date == null) return '—';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  return '$hour:${_two(date.minute)} ${date.hour >= 12 ? 'PM' : 'AM'}';
}

/// Stable day key, yyyy-MM-dd.
String dayKey(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

/// "just now", "12 min ago", "3 h ago", "Yesterday", "Nov 7".
String timeAgo(DateTime? date) {
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return dateLabel(date);
}

/// "In 3 days" / "Today" / "2 days ago".
String relativeDay(DateTime? date) {
  if (date == null) return '—';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final days = target.difference(today).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days == -1) return 'Yesterday';
  if (days > 1) return 'In $days days';
  return '${-days} days ago';
}
