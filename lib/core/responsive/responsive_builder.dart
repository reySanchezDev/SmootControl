import 'package:flutter/widgets.dart';
import 'package:smoo_control/core/responsive/responsive_breakpoints.dart';

/// Builds layouts using the official responsive breakpoints.
class ResponsiveBuilder extends StatelessWidget {
  /// Creates a responsive builder.
  const ResponsiveBuilder({
    required this.builder,
    super.key,
  });

  /// Builder receiving the current responsive size.
  final Widget Function(BuildContext context, ResponsiveSize size) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = switch (constraints.maxWidth) {
          <= ResponsiveBreakpoints.mobileMax => ResponsiveSize.mobile,
          <= ResponsiveBreakpoints.tabletMax => ResponsiveSize.tablet,
          _ => ResponsiveSize.desktop,
        };

        return builder(context, size);
      },
    );
  }
}
