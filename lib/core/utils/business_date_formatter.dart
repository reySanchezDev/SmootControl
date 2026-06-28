/// Formats and parses business dates used by local persistence.
abstract final class BusinessDateFormatter {
  /// Formats a [DateTime] as yyyy-MM-dd.
  static String format(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  /// Parses a yyyy-MM-dd business date.
  static DateTime parse(String value) {
    final parts = value.split('-').map(int.parse).toList();

    return DateTime(parts[0], parts[1], parts[2]);
  }
}
