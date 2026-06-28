import 'package:equatable/equatable.dart';

/// Group of options that must be selected when selling a product.
final class ProductOptionGroup extends Equatable {
  /// Creates a product option group.
  const ProductOptionGroup({
    required this.name,
    required this.options,
    this.isRequired = true,
  });

  /// Visible group name, for example Acompanamiento or Base.
  final String name;

  /// Available option names.
  final List<String> options;

  /// Whether the POS must receive one option from this group.
  final bool isRequired;

  /// Whether the group has usable options.
  bool get isUsable => name.trim().isNotEmpty && options.isNotEmpty;

  @override
  List<Object?> get props => [name, options, isRequired];
}

/// Selected option copied to the POS cart and sale history.
final class SelectedProductOption extends Equatable {
  /// Creates a selected product option.
  const SelectedProductOption({
    required this.groupName,
    required this.optionName,
  });

  /// Group selected by the cashier or waiter.
  final String groupName;

  /// Chosen option inside the group.
  final String optionName;

  @override
  List<Object?> get props => [groupName, optionName];
}
