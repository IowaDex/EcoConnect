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
  /// Matching is case-insensitive and ignores surrounding spaces so a value
  /// typed by hand (or an older record) still compares correctly.
  static bool covers(String? barangayName) {
    final value = (barangayName ?? '').trim().toLowerCase();
    return value == barangay.toLowerCase();
  }
}
