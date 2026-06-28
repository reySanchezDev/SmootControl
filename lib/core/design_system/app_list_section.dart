import 'package:flutter/material.dart';

/// Consistent list container for loaded module data.
class AppListSection extends StatelessWidget {
  /// Creates a list section.
  const AppListSection({
    required this.children,
    super.key,
  });

  /// List children.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => children[index],
      itemCount: children.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
    );
  }
}
