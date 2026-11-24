/// The single barangay EcoConnect is deployed for.
///
/// The app is not a nationwide service: only residents of Barangay Batasan
/// Hills, Quezon City may register. The value is enforced in three places —
/// the sign-up form (locked fields), the login gate (an existing account from
/// another barangay is refused), and `firestore.rules` (a client cannot write
/// a resident profile for anywhere else).
class ServiceArea {
  const ServiceArea._();

  static const barangay = 'Batasan Hills';
  static const city = 'Quezon City';
  static const province = 'Metro Manila';

  static const displayName = 'Barangay Batasan Hills, Quezon City';

  /// True when [barangayName] is the barangay this deployment serves.
  ///
  /// Matching is case-insensitive, ignores surrounding spaces, drops a leading
  /// "Barangay"/"Brgy." prefix and accepts the barangay followed by the city,
  /// so a value typed by hand — or written by an older build as
  /// "Batasan Hills, Quezon City" — still compares correctly.
  static bool covers(String? barangayName) {
    final value = _normalize(barangayName);
    return value == _key || value.startsWith('$_key,');
  }

  /// True when a record belongs on this deployment's desk.
  ///
  /// Same as [covers], except that a blank barangay counts as ours and a
  /// barangay written as part of a full address still counts. The app only
  /// ever writes this one barangay, so a record without one is an old record,
  /// not a record from somewhere else. The collection desk uses this so it can
  /// never drop a request the dashboard is counting.
  static bool belongsToArea(String? barangayName) {
    final value = _normalize(barangayName);
    return value.isEmpty || value.contains(_key);
  }

  static String _normalize(String? barangayName) {
    var value = (barangayName ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    for (final prefix in _prefixes) {
      if (value.startsWith(prefix)) {
        value = value.substring(prefix.length).trim();
        break;
      }
    }
    return value;
  }

  static const _prefixes = ['barangay ', 'brgy. ', 'brgy ', 'bgy. ', 'bgy '];

  static final _key = barangay.toLowerCase();
}
