/// Formats and parses user-facing money values.
final class MoneyFormatter {
  const MoneyFormatter._();

  /// Currency prefix used by the initial Spanish-only business flows.
  static const symbol = r'C$';

  /// Formats cents as a visible currency amount.
  static String format(int cents) {
    final sign = cents < 0 ? '-' : '';
    final absoluteCents = cents.abs();
    final whole = absoluteCents ~/ 100;
    final decimals = (absoluteCents % 100).toString().padLeft(2, '0');
    return '$symbol $sign${_formatThousands(whole)}.$decimals';
  }

  /// Parses a decimal currency input into cents.
  static int? parseToCents(String value) {
    var normalized = value.trim().replaceAll(symbol, '').replaceAll(' ', '');

    if (normalized.isEmpty) {
      return null;
    }

    final negative = normalized.startsWith('-');
    if (negative) {
      normalized = normalized.substring(1);
    }

    if (normalized.contains(',') && normalized.contains('.')) {
      normalized = normalized.replaceAll(',', '');
    } else if (normalized.contains(',')) {
      normalized = _looksLikeThousands(normalized)
          ? normalized.replaceAll(',', '')
          : normalized.replaceAll(',', '.');
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

    final cents = whole * 100 + int.parse(decimal.padRight(2, '0'));
    return negative ? -cents : cents;
  }

  static String _formatThousands(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final fromRight = digits.length - index;
      buffer.write(digits[index]);
      if (fromRight > 1 && fromRight % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  static bool _looksLikeThousands(String value) {
    return RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(value);
  }
}
