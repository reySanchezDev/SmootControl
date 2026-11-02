import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/theme/app_theme.dart';
import 'package:smoo_control/core/theme/backoffice_theme.dart';

double _channel(double value) {
  if (value <= 0.04045) return value / 12.92;
  return math.pow((value + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color color) =>
    0.2126 * _channel(color.r) +
    0.7152 * _channel(color.g) +
    0.0722 * _channel(color.b);

double _contrast(Color a, Color b) {
  final first = _luminance(a);
  final second = _luminance(b);
  return (math.max(first, second) + 0.05) /
      (math.min(first, second) + 0.05);
}

void main() {
  test('Admin theme is separate from app and tablet/POS theme', () {
    final app = AppTheme.light.colorScheme;
    final admin = BackofficeTheme.executiveIvory.colorScheme;
    expect(admin.primary, BackofficeDesignTokens.primary);
    expect(app.primary, isNot(admin.primary));
    expect(AppTheme.light.colorScheme.primary, app.primary);
  });

  test('UX-039: administrative primary action text has AA contrast', () {
    final colors = BackofficeTheme.executiveIvory.colorScheme;
    expect(_contrast(colors.primary, colors.onPrimary), greaterThanOrEqualTo(4.5));
  });
}
