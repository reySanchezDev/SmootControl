import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';

/// Helpers for nested payment method navigation.
final class PaymentMethodTreeService {
  const PaymentMethodTreeService._();

  /// Returns children for a parent sorted for POS and maintenance.
  static List<PaymentMethod> childrenOf(
    List<PaymentMethod> methods,
    String? parentId,
  ) {
    return methods.where((method) => method.parentId == parentId).toList()
      ..sort(_compareMethods);
  }

  /// Returns non-chargeable nodes that can receive child methods.
  static List<PaymentMethod> parentCandidates(
    List<PaymentMethod> methods, {
    String? excludedId,
  }) {
    final excluded = _descendantIds(methods, excludedId);
    return methods.where((method) {
      if (method.isPaymentTarget) return false;
      return !excluded.contains(method.id);
    }).toList()..sort(_compareMethods);
  }

  /// Returns a human-readable path for a payment node.
  static String pathFor(List<PaymentMethod> methods, PaymentMethod method) {
    final byId = {for (final entry in methods) entry.id: entry};
    final names = <String>[method.name];
    var parent = byId[method.parentId];
    while (parent != null) {
      names.insert(0, parent.name);
      parent = byId[parent.parentId];
    }
    return names.join(' > ');
  }

  static Set<String> _descendantIds(
    List<PaymentMethod> methods,
    String? rootId,
  ) {
    if (rootId == null) return const {};
    final result = <String>{rootId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final method in methods) {
        if (method.parentId != null &&
            result.contains(method.parentId) &&
            result.add(method.id)) {
          changed = true;
        }
      }
    }
    return result;
  }

  static int _compareMethods(PaymentMethod first, PaymentMethod second) {
    final order = first.displayOrder.compareTo(second.displayOrder);
    if (order != 0) return order;
    return first.name.compareTo(second.name);
  }
}
