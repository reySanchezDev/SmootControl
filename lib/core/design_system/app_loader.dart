import 'package:flutter/material.dart';

/// Standard centered loading indicator.
class AppLoader extends StatelessWidget {
  /// Creates a loader.
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
