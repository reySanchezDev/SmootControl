import 'package:flutter/material.dart';

/// Supported typography variants for [AppText].
enum AppTextVariant {
  /// Large page title.
  titleLarge,

  /// Medium section title.
  titleMedium,

  /// Standard body text.
  body,

  /// Small supporting text.
  label,
}

/// Project text widget used instead of direct [Text] usage in UI code.
class AppText extends StatelessWidget {
  /// Creates a design-system text widget.
  const AppText(
    this.data, {
    this.maxLines,
    this.overflow,
    this.style,
    this.textAlign,
    this.variant = AppTextVariant.body,
    super.key,
  });

  /// Text content.
  final String data;

  /// Typography variant.
  final AppTextVariant variant;

  /// Maximum number of visual lines.
  final int? maxLines;

  /// Overflow behavior.
  final TextOverflow? overflow;

  /// Optional style merged with the selected typography variant.
  final TextStyle? style;

  /// Text alignment.
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final baseStyle = switch (variant) {
      AppTextVariant.titleLarge => textTheme.headlineMedium,
      AppTextVariant.titleMedium => textTheme.titleLarge,
      AppTextVariant.body => textTheme.bodyLarge,
      AppTextVariant.label => textTheme.labelLarge,
    };
    final effectiveStyle = style == null
        ? baseStyle
        : baseStyle?.merge(style) ?? style;

    return Text(
      data,
      maxLines: maxLines,
      overflow: overflow,
      style: effectiveStyle,
      textAlign: textAlign,
    );
  }
}
