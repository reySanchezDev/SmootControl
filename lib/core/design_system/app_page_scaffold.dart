import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/navigation/backoffice_workspace.dart';

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
    final insideWorkspace = BackofficeWorkspaceScope.contains(context);
    return Scaffold(
      appBar: showAppBar && !insideWorkspace
          ? AppBar(
              actions: actions,
              toolbarHeight: 72,
              title: AppText(
                title,
                variant: AppTextVariant.titleMedium,
              ),
            )
          : null,
      body: SafeArea(
        child: insideWorkspace && showAppBar && actions != null &&
                actions!.isNotEmpty
            ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions!,
                    ),
                  ),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
    );
  }
}
