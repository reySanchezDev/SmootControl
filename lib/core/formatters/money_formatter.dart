/// Formats and parses user-facing money values.
final class MoneyFormatter {
  const MoneyFormatter._();

  /// Currency prefix used by the initial Spanish-only business flows.
  static const symbol = r'C$';

  /// Formats cents as a visible currency amount.
  static String format(int cents) {
    return '$symbol ${(cents / 100).toStringAsFixed(2)}';
  }

  /// Parses a decimal currency input into cents.
  static int? parseToCents(String value) {
    final normalized = value
        .trim()
        .replaceAll(symbol, '')
        .replaceAll(',', '.')
        .replaceAll(' ', '');

    if (normalized.isEmpty) {
      return null;
    }

    final parts = normalized.split('.');
    if (parts.length > 2 || parts.first.isEmpty) {
      return null;
    }

    final whole = int.tryParse(parts.first);
    if (whole == null) {
      return null;
    }

    final decimal = parts.length == 1 ? '' : parts.last;
    if (decimal.length > 2 || int.tryParse(decimal.padRight(2, '0')) == null) {
      return null;
    }

    return whole * 100 + int.parse(decimal.padRight(2, '0'));
  }
}
