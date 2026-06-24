class SearchIndexUtils {
  const SearchIndexUtils._();

  static String normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<String> keywords(Iterable<String?> values) {
    final tokens = <String>{};
    for (final value in values) {
      if (value == null) continue;
      final normalized = normalize(value);
      if (normalized.isEmpty) continue;

      tokens.add(normalized);
      for (final token in normalized.split(RegExp(r'[^a-z0-9]+'))) {
        if (token.length >= 2) {
          tokens.add(token);
          for (var i = 2; i <= token.length && i <= 20; i++) {
            tokens.add(token.substring(0, i));
          }
        }
      }
    }
    return tokens.toList()..sort();
  }
}
