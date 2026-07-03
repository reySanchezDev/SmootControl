import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';

void main() {
  test('formats cents with thousands separators', () {
    expect(MoneyFormatter.format(0), r'C$ 0.00');
    expect(MoneyFormatter.format(358900), r'C$ 3,589.00');
    expect(MoneyFormatter.format(123456789), r'C$ 1,234,567.89');
  });

  test('parses formatted and plain money values', () {
    expect(MoneyFormatter.parseToCents(r'C$ 3,589.00'), 358900);
    expect(MoneyFormatter.parseToCents('3589.00'), 358900);
    expect(MoneyFormatter.parseToCents('36,60'), 3660);
    expect(MoneyFormatter.parseToCents('1,000'), 100000);
  });
}
