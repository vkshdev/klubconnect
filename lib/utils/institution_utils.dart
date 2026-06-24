class InstitutionUtils {
  const InstitutionUtils._();

  static String idFromCollegeName(String collegeName) {
    final normalized = collegeName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    return normalized.isEmpty ? 'unknown-institution' : normalized;
  }
}
