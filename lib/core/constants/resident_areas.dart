/// The subdivisions, villages and sitios inside Barangay Batasan Hills that a
/// resident may register under.
///
/// One flat list, alphabetised only by the barangay's own grouping — the
/// sign-up picker never splits it into sections, so the resident scrolls or
/// searches a single column.
class ResidentAreas {
  const ResidentAreas._();

  /// Chosen when the resident's area is not in [all]; the form then asks them
  /// to type it in.
  static const String other = 'Other / Not Listed';

  static const List<String> all = [
    'Filinvest 1',
    'Filinvest 2',
    'Filinvest Heights',
    'Northview 1',
    'Northview 2',
    'Northview Villas',
    'Vista Real Executive Village',
    'Vista Real Classica',
    'Ciudad Regina',
    'Luzviminda Village',
    'Sugartowne',
    'Sugartowne Homes',
    'Sunnyside Heights',
    'Spring Country',
    'Capitol Ridge',
    'New Capitol Estates',
    'Capitol Bliss',
    'Villa Amor Uno',
    'Doña Pilar',
    'Doña Ana',
    'Doña Juana',
    'Tivoli Royale',
    'Tivoli Greens',
    'Violago Homes',
    'Nelson Ville I',
    'Garland',
    'Sierra Monte',
    'Talanay',
    'Talanay Area B',
    'Talanay Area C',
    'Sitio Taniman',
    'Sitio Kaliwa',
    'Shelter Homes',
    'Kalayaan A',
    'Kalayaan B',
    'Kalayaan C',
    'Constitution Hills',
    other,
  ];

  /// True when [value] means "my area is not on this list".
  static bool isOther(String? value) => value == other;
}
