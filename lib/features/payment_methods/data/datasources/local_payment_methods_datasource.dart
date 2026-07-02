import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/payment_methods/data/models/payment_method_model.dart';

/// Local datasource for payment methods.
final class LocalPaymentMethodsDataSource {
  /// Creates a local payment methods datasource.
  const LocalPaymentMethodsDataSource(this._database);

  final AppDatabase _database;

  /// Returns payment methods stored locally.
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    final query = _database.select(_database.localPaymentMethods)
      ..orderBy([
        (method) => OrderingTerm.asc(method.groupName),
        (method) => OrderingTerm.asc(method.parentId),
        (method) => OrderingTerm.asc(method.displayOrder),
        (method) => OrderingTerm.asc(method.name),
      ]);
    final rows = await query.get();

    return rows.map(PaymentMethodModel.fromLocal).toList();
  }

  /// Inserts or updates a local payment method.
  Future<PaymentMethodModel> savePaymentMethod(
    PaymentMethodModel method,
  ) async {
    final now = DateTime.now();

    await _database
        .into(_database.localPaymentMethods)
        .insertOnConflictUpdate(
          LocalPaymentMethodsCompanion(
            id: Value(method.id),
            name: Value(method.name),
            parentId: Value(method.parentId),
            groupName: Value(method.groupName),
            currencyCode: Value(method.currencyCode),
            displayOrder: Value(method.displayOrder),
            isPaymentTarget: Value(method.isPaymentTarget),
            affectsCashRegister: Value(method.affectsCashRegister),
            requiresReference: Value(method.requiresReference),
            isActive: Value(method.isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return method;
  }

  /// Deletes one payment level and moves direct children to its parent.
  Future<void> removePaymentMethodLevel({
    required String methodId,
    required String parentId,
  }) async {
    final now = DateTime.now();

    await _database.transaction(() async {
      await (_database.update(
        _database.localPaymentMethods,
      )..where((method) => method.parentId.equals(methodId))).write(
        LocalPaymentMethodsCompanion(
          parentId: Value(parentId),
          updatedAt: Value(now),
        ),
      );

      await (_database.delete(
        _database.localPaymentMethods,
      )..where((method) => method.id.equals(methodId))).go();
    });
  }

  /// Deletes one payment method that does not have children.
  Future<void> deletePaymentMethod(String methodId) async {
    await (_database.delete(
      _database.localPaymentMethods,
    )..where((method) => method.id.equals(methodId))).go();
  }

  /// Returns whether the payment method has direct child nodes.
  Future<bool> hasChildren(String methodId) async {
    final query = _database.select(_database.localPaymentMethods)
      ..where((method) => method.parentId.equals(methodId))
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }
}
