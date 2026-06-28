import 'package:flutter/material.dart';

/// Standard search field used by catalog and transaction lists.
class AppSearchField extends StatelessWidget {
  /// Creates an application search field.
  const AppSearchField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.onClear,
    super.key,
  });

  /// Field controller.
  final TextEditingController controller;

  /// Localized field label.
  final String label;

  /// Notifies the owner when the query changes.
  final ValueChanged<String> onChanged;

  /// Optional callback when the query is cleared.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClear,
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              ),
      ),
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
    );
  }
}
