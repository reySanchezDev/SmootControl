import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_loader.dart';

/// Centered loading content for pages.
class AppLoadingPage extends StatelessWidget {
  /// Creates a loading page.
  const AppLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: AppLoader());
  }
}
