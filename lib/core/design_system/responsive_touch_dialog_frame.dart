import 'package:flutter/material.dart';

/// Responsive frame for touch-first dialogs used by POS flows.
class ResponsiveTouchDialogFrame extends StatelessWidget {
  /// Creates a responsive touch dialog frame.
  const ResponsiveTouchDialogFrame({
    required this.content,
    required this.title,
    this.actions = const [],
    this.maxWidth = 720,
    this.padding = const EdgeInsets.all(14),
    super.key,
  });

  /// Dialog title.
  final Widget title;

  /// Scrollable dialog body.
  final Widget content;

  /// Footer actions kept reachable below the scrollable body.
  final List<Widget> actions;

  /// Maximum dialog width on large screens.
  final double maxWidth;

  /// Inner padding around title, body and footer.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final dialogWidth = (mediaSize.width * .94).clamp(280.0, maxWidth);
    final dialogHeight = mediaSize.height * .92;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: dialogHeight,
          maxWidth: dialogWidth,
        ),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(child: content),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  runSpacing: 8,
                  spacing: 8,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
