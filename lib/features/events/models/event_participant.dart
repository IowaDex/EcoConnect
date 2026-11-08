import 'package:cloud_firestore/cloud_firestore.dart';

/// A leading house number: "12", "12a", "24-b", "24-26". Ordinals such as
/// "1st" or "5th" are street names ("5th Ave"), so they never match.
final _houseNumber = RegExp(r'^(?:\d+[a-z]?(?:-\d*[a-z]?)?|-+)$');

/// "unit 4b", "blk 7 lot 12", "#12", "no. 12" prefixes. A marker only counts
/// when a number follows it, so streets such as "Northville", "Lotus" or
/// "Houseman" keep their names.
final _markerPrefix = RegExp(
  r'^(?:(?:unit|blk|block|lot|house|no\.?)\s*#?\s*\d[\w\-]*\s*'
  r'|#\s*\d[\w\-]*\s*)+',
);

/// Turns a free-text street into a bucket key.
///
/// `houseStreet` is typed by the resident ("House no/Unit/street"), so the same
/// street arrives as "12 Mabini St.", "mabini street" or "Mabini St". Without
/// normalising it, every resident becomes their own one-person street and the
/// ranking is meaningless. Strip the house number and punctuation, lowercase,
/// collapse whitespace, and fold "street" into "st".
String streetKeyOf(String? raw) {
  if (raw == null) return '';
  var s = raw.toLowerCase().trim().replaceAll(_markerPrefix, '');
  s = s.replaceAll(RegExp(r'[^a-z0-9\s\-]'), ' ');
  final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  while (words.isNotEmpty && _houseNumber.hasMatch(words.first)) {
    words.removeAt(0);
  }
  s = words
      .join(' ')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return s.replaceAll(RegExp(r'\bstreet$'), 'st');
}

/// One resident signed up for one event.
///
/// Stored at `events/{eventId}/participants/{uid}`. The street is copied in at
/// join time rather than looked up later, so the ranking still works if the
/// resident edits their profile afterwards.
class EventParticipant {
  const EventParticipant({
    required this.uid,
    required this.name,
    required this.street,
    required this.streetKey,
    required this.barangay,
    this.joinedAt,
  });

  final String uid;
  final String name;

  /// Raw street as typed by the resident.
  final String street;

  /// [streetKeyOf] of [street] — the ranking bucket.
  final String streetKey;

  final String barangay;
  final DateTime? joinedAt;

  /// What to print when the street is unknown.
  String get streetLabel => street.trim().isEmpty ? 'Street not set' : street;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'street': street,
        'streetKey': streetKey,
        'barangay': barangay,
        'joinedAt': FieldValue.serverTimestamp(),
      };

  static EventParticipant fromDoc(String uid, Map<String, dynamic> data) {
    final street = (data['street'] as String?) ?? '';
    return EventParticipant(
      uid: uid,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : 'Resident',
      street: street,
      // Derived from the street text, not the stored key: a stored key could be
      // forged by a modified app, and rows written before a key fix stay right.
      streetKey: street.trim().isNotEmpty
          ? streetKeyOf(street)
          : ((data['streetKey'] as String?) ?? ''),
      barangay: (data['barangay'] as String?) ?? '',
      joinedAt:
          data['joinedAt'] is Timestamp ? (data['joinedAt'] as Timestamp).toDate() : null,
    );
  }
}

/// A street's standing across every event.
class StreetStanding {
  const StreetStanding({
    required this.key,
    required this.label,
    required this.residents,
    required this.attendances,
    required this.events,
  });

  /// Normalised bucket key.
  final String key;

  /// Display name — the first spelling seen for this bucket.
  final String label;

  /// Distinct residents from this street who joined at least one event.
  final int residents;

  /// Total joins across every event. One resident joining three events counts
  /// three times — this is what the ranking is based on.
  final int attendances;

  /// Distinct events this street showed up to.
  final int events;

  /// Leaderboard score. Ten points per attendance keeps the numbers readable
  /// next to the recycling points residents already earn.
  int get points => attendances * 10;
}
