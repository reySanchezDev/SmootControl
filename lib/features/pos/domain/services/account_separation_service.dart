import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/pos/domain/entities/account_split_draft.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item_draft.dart';

/// Validates the split-account flow before a table is separated.
final class AccountSeparationService {
  /// Creates the account separation service.
  const AccountSeparationService();

  /// Validates that every product belongs to exactly one account.
  AppResult<List<AccountSplitDraft>> validate({
    required List<SaleItemDraft> tableItems,
    required List<AccountSplitDraft> accounts,
  }) {
    if (tableItems.isEmpty) {
      return const AppFailureResult(
        AppFailure(
          code: 'table_without_items',
          message: 'La mesa no tiene productos para separar.',
        ),
      );
    }

    if (accounts.length < 2) {
      return const AppFailureResult(
        AppFailure(
          code: 'not_enough_accounts',
          message: 'Debe crear al menos dos cuentas.',
        ),
      );
    }

    final validItemIds = tableItems.map((item) => item.id).toSet();
    final assignedIds = <String>[];

    for (final account in accounts) {
      if (account.name.trim().isEmpty) {
        return const AppFailureResult(
          AppFailure(
            code: 'account_without_name',
            message: 'Todas las cuentas deben tener nombre.',
          ),
        );
      }

      if (account.itemIds.isEmpty) {
        return AppFailureResult(
          AppFailure(
            code: 'account_without_items',
            message: 'La cuenta ${account.name} no tiene productos.',
          ),
        );
      }

      assignedIds.addAll(account.itemIds);
    }

    final assignedSet = assignedIds.toSet();
    final hasDuplicates = assignedSet.length != assignedIds.length;
    if (hasDuplicates) {
      return const AppFailureResult(
        AppFailure(
          code: 'duplicated_items',
          message: 'Un producto no puede quedar en dos cuentas.',
        ),
      );
    }

    final hasUnknownItem = assignedSet.any((id) => !validItemIds.contains(id));
    if (hasUnknownItem) {
      return const AppFailureResult(
        AppFailure(
          code: 'unknown_items',
          message: 'Hay productos asignados que no pertenecen a la mesa.',
        ),
      );
    }

    final pendingIds = validItemIds.difference(assignedSet);
    if (pendingIds.isNotEmpty) {
      return const AppFailureResult(
        AppFailure(
          code: 'pending_items',
          message: 'Todos los productos deben asignarse a una cuenta.',
        ),
      );
    }

    return AppSuccess(accounts);
  }
}
