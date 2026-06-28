part of 'product_option_groups_editor.dart';

final class _OptionGroupDraft {
  _OptionGroupDraft({
    required this.nameController,
    required this.optionControllers,
    required this.isRequired,
  });

  factory _OptionGroupDraft.empty() {
    return _OptionGroupDraft(
      nameController: _controller(),
      optionControllers: [_controller()],
      isRequired: true,
    );
  }

  factory _OptionGroupDraft.from(ProductOptionGroup group) {
    return _OptionGroupDraft(
      nameController: _controller(group.name),
      optionControllers: [
        for (final option in group.options) _controller(option),
      ],
      isRequired: group.isRequired,
    );
  }

  final TextEditingController nameController;
  final List<TextEditingController> optionControllers;
  bool isRequired;

  _OptionGroupDraftValue? toValue() {
    final name = nameController.text.trim();
    final options = [
      for (final controller in optionControllers) controller.text.trim(),
    ];
    final hasAnyInput =
        name.isNotEmpty || options.any((option) => option != '');
    if (!hasAnyInput) return null;

    final validOptions = options.where((option) => option.isNotEmpty).toList();
    final hasInvalidInput =
        name.isEmpty ||
        validOptions.isEmpty ||
        validOptions.length != optionControllers.length;

    if (hasInvalidInput) {
      return const _OptionGroupDraftValue.invalid();
    }

    return _OptionGroupDraftValue.valid(
      ProductOptionGroup(
        name: name,
        options: validOptions,
        isRequired: isRequired,
      ),
    );
  }

  void dispose() {
    nameController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
  }
}

final class _OptionGroupDraftValue {
  const _OptionGroupDraftValue.valid(this.group) : hasInvalidInput = false;

  const _OptionGroupDraftValue.invalid() : group = null, hasInvalidInput = true;

  final ProductOptionGroup? group;
  final bool hasInvalidInput;
}

TextEditingController _controller([String? text]) {
  return TextEditingController(text: text);
}
