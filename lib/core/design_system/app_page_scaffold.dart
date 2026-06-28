import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';

/// Shared scaffold for application pages.
class AppPageScaffold extends StatelessWidget {
  /// Creates a page scaffold.
  const AppPageScaffold({
    required this.body,
    required this.title,
    this.actions,
    this.showAppBar = true,
    super.key,
  });

  /// Page title.
  final String title;

  /// Page action widgets.
  final List<Widget>? actions;

  /// Whether the page app bar should be displayed.
  final bool showAppBar;

  /// Page body.
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              actions: actions,
              title: AppText(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                variant: AppTextVariant.titleMedium,
              ),
            )
          : null,
      body: SafeArea(child: body),
    );
  }
}
