import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// User-facing row for a local sync queue item.
class SyncQueueTile extends StatelessWidget {
  /// Creates a sync queue tile.
  const SyncQueueTile({required this.item, super.key});

  /// Queue item to show.
  final SyncQueueItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final createdAt = DateFormat.yMd('es').add_Hm().format(item.createdAt);
    final detail = [
      _operationLabel(l10n),
      _statusLabel(l10n),
      createdAt,
      if (item.retryCount > 0) l10n.syncRetryCount(item.retryCount),
      if (item.lastError != null) '${l10n.syncLastError}: ${item.lastError}',
    ].join(' - ');

    return ListTile(
      leading: Icon(_statusIcon()),
      subtitle: AppText(
        detail,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        variant: AppTextVariant.label,
      ),
      title: AppText(_entityLabel(l10n)),
    );
  }

  IconData _statusIcon() {
    return switch (item.status) {
      SyncQueueStatus.pending => Icons.cloud_queue_outlined,
      SyncQueueStatus.syncing => Icons.sync,
      SyncQueueStatus.synced => Icons.cloud_done_outlined,
      SyncQueueStatus.error => Icons.sync_problem_outlined,
    };
  }

  String _operationLabel(AppLocalizations l10n) {
    return switch (item.operation) {
      SyncOperation.create => l10n.syncOperationCreate,
      SyncOperation.update => l10n.syncOperationUpdate,
      SyncOperation.delete => l10n.syncOperationDelete,
    };
  }

  String _statusLabel(AppLocalizations l10n) {
    return switch (item.status) {
      SyncQueueStatus.pending => l10n.syncStatusPending,
      SyncQueueStatus.syncing => l10n.syncStatusSyncing,
      SyncQueueStatus.synced => l10n.syncStatusSynced,
      SyncQueueStatus.error => l10n.syncStatusError,
    };
  }

  String _entityLabel(AppLocalizations l10n) {
    return switch (item.entityType) {
      'product_categories' => l10n.moduleCatalog,
      'products' => l10n.moduleProducts,
      'payment_methods' => l10n.modulePaymentMethods,
      'restaurant_tables' => l10n.moduleTables,
      'table_accounts' => l10n.splitAccountsTitle,
      'sales' || 'sale' => l10n.moduleSales,
      'cash_register_sessions' => l10n.moduleCashRegister,
      'expense_categories' => l10n.expenseCategoriesSection,
      'operating_expenses' || 'expense' => l10n.moduleExpenses,
      'business_settings' => l10n.moduleSettings,
      'roles' => l10n.moduleRoles,
      'permissions' || 'role_permissions' => l10n.permissionsSection,
      'profiles' => l10n.moduleUsers,
      'audit_logs' => l10n.moduleAudit,
      'salary_advances' => 'Adelantos de salario',
      _ => l10n.moduleSync,
    };
  }
}
