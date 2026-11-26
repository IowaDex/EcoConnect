/// Matches a resident's registered area against the areas a route covers.
///
/// Residents pick their area at sign-up from `ResidentAreas.all`, and Iswim
/// picks the same names when it builds a collection manual. The two records are
/// written by different desks months apart, so the comparison ignores case,
/// spacing and punctuation instead of trusting a byte-for-byte match.
///
/// A route label can hold several areas joined with `·`, `/` or `,` (a manual
/// stores `routesLabel` that way), so it is split before matching.
library;

/// Accented letters folded to their plain form, so "Doña Pilar" and
/// "DONA PILAR" are the same place. Only the marks that appear in Philippine
/// place names are covered; anything else is left alone.
const Map<String, String> _folded = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ñ': 'n',
  'ç': 'c',
};

/// Lower-case, punctuation-free form used for every comparison.
String normalizeAreaName(String value) {
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_folded[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// The individual area names inside one route label.
///
/// `"Filinvest 1 · Filinvest 2"` becomes two names. A label that is a single
/// street keeps its whole text, which simply never equals a resident area.
List<String> splitAreaNames(String value) => value
    .split(RegExp(r'\s*(?:·|/|,|;|\|)\s*'))
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList(growable: false);

/// True when [residentArea] is one of the areas in [routeAreas].
///
/// An empty resident area never matches: without knowing where the resident
/// lives, sending them another area's schedule would be a false alarm.
bool areaServesResident(String? residentArea, Iterable<String> routeAreas) {
  final area = normalizeAreaName(residentArea ?? '');
  if (area.isEmpty) return false;
  for (final raw in routeAreas) {
    for (final part in splitAreaNames(raw)) {
      if (normalizeAreaName(part) == area) return true;
    }
  }
  return false;
}

/// Every distinct area name in [routeAreas], for a notification body.
List<String> uniqueAreaNames(Iterable<String> routeAreas) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in routeAreas) {
    for (final part in splitAreaNames(raw)) {
      if (seen.add(normalizeAreaName(part))) out.add(part);
    }
  }
  return out;
}
