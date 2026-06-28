/// Normalizes text for user-facing search comparisons.
String normalizeSearchText(String value) {
  final lower = value.trim().toLowerCase();
  return lower
      .replaceAll(RegExp('[áàäâ]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöô]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u')
      .replaceAll('ñ', 'n');
}

/// Returns whether [source] contains [query] using normalized text.
bool containsNormalizedSearch(String source, String query) {
  final normalizedQuery = normalizeSearchText(query);
  if (normalizedQuery.isEmpty) return true;

  return normalizeSearchText(source).contains(normalizedQuery);
}
