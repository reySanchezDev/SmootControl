import 'package:flutter/material.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method_pos_display.dart';
import 'package:smoo_control/features/payment_methods/domain/services/payment_method_tree_service.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_payment_flow.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_touch_grid.dart';

const _legacyPrefix = 'legacy-group:';

/// Tactile hierarchical payment navigation for the POS.
class PosPaymentSection extends StatelessWidget {
  /// Creates the payment section.
  const PosPaymentSection({
    required this.onPaymentParentChanged,
    required this.paymentParentKey,
    required this.state,
    this.onPaymentCompleted,
    super.key,
  });

  /// Current parent node key. Legacy groups use an internal prefix.
  final String? paymentParentKey;

  /// Payment navigation change callback.
  final ValueChanged<String?> onPaymentParentChanged;

  /// Current POS state.
  final PosReady state;

  /// Optional callback invoked after a payment request is dispatched.
  final VoidCallback? onPaymentCompleted;

  @override
  Widget build(BuildContext context) {
    return PosTouchGrid(
      minTileHeight: 52,
      minTileWidth: 118,
      children: _buttons(context),
    );
  }

  List<Widget> _buttons(BuildContext context) {
    final key = paymentParentKey;
    if (key == null) return _rootButtons(context);
    if (key.startsWith(_legacyPrefix)) {
      return _legacyMethodButtons(context, key.substring(_legacyPrefix.length));
    }
    return _childButtons(context, key);
  }

  List<Widget> _rootButtons(BuildContext context) {
    final active = _activeMethods();
    final realRoots = PaymentMethodTreeService.childrenOf(active, null);
    final rootNames = realRoots.map((method) => method.name).toSet();
    final legacyGroups = _legacyGroups(active, rootNames);

    return [
      for (final method in realRoots) _methodButton(context, method),
      for (final group in legacyGroups)
        PosTouchButton(
          label: group,
          onPressed: () => onPaymentParentChanged('$_legacyPrefix$group'),
        ),
    ];
  }

  List<Widget> _childButtons(BuildContext context, String parentId) {
    final methods = PaymentMethodTreeService.childrenOf(
      _activeMethods(),
      parentId,
    );
    return [
      for (final method in methods) _methodButton(context, method),
      _backButton(parentId),
    ];
  }

  List<Widget> _legacyMethodButtons(BuildContext context, String group) {
    final methods = _activeMethods().where((method) {
      return method.parentId == null &&
          method.isPaymentTarget &&
          method.posGroupName == group;
    }).toList()..sort(_compareMethods);

    return [
      for (final method in methods) _finalPaymentButton(context, method),
      _backButton(null),
    ];
  }

  Widget _methodButton(BuildContext context, PaymentMethod method) {
    final hasChildren = _activeMethods().any((entry) {
      return entry.parentId == method.id;
    });
    if (hasChildren || !method.isPaymentTarget) {
      return PosTouchButton(
        label: method.name,
        onPressed: () => onPaymentParentChanged(method.id),
      );
    }
    return _finalPaymentButton(context, method);
  }

  Widget _finalPaymentButton(BuildContext context, PaymentMethod method) {
    return PosTouchButton(
      label: method.posOptionName,
      onPressed: state.cartLines.isEmpty
          ? null
          : () => _startPaymentFlow(context, method),
      selected: state.selectedPaymentMethodId == method.id,
    );
  }

  Widget _backButton(String? parentId) {
    return PosTouchButton(
      label: 'Regresar',
      onPressed: () => onPaymentParentChanged(_parentOf(parentId)),
      tone: PosButtonTone.neutral,
    );
  }

  String? _parentOf(String? parentId) {
    if (parentId == null) return null;
    for (final method in state.paymentMethods) {
      if (method.id == parentId) return method.parentId;
    }
    return null;
  }

  List<PaymentMethod> _activeMethods() {
    return state.paymentMethods.where((method) => method.isActive).toList();
  }

  List<String> _legacyGroups(
    List<PaymentMethod> methods,
    Set<String> realRootNames,
  ) {
    final groups = <String>{};
    for (final method in methods) {
      if (method.parentId != null || !method.isPaymentTarget) continue;
      final group = method.posGroupName;
      if (!realRootNames.contains(group)) groups.add(group);
    }
    return groups.toList()..sort();
  }

  Future<void> _startPaymentFlow(
    BuildContext context,
    PaymentMethod method,
  ) async {
    await startPosPaymentFlow(
      context: context,
      method: method,
      onPaymentCompleted: onPaymentCompleted,
      state: state,
    );
  }

  int _compareMethods(PaymentMethod first, PaymentMethod second) {
    final order = first.displayOrder.compareTo(second.displayOrder);
    if (order != 0) return order;
    return first.posOptionName.compareTo(second.posOptionName);
  }
}
