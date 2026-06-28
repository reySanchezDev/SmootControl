import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// User-facing audit log row.
class AuditLogTile extends StatelessWidget {
  /// Creates an audit log tile.
  const AuditLogTile({required this.entry, super.key});

  /// Audit entry to display.
  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final time = DateFormat.Hm('es').format(entry.occurredAt);
    final details = _detailsLabel(l10n);

    return ListTile(
      leading: const Icon(Icons.history_outlined),
      subtitle: AppText(
        details.isEmpty ? time : '$time - $details',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        variant: AppTextVariant.label,
      ),
      title: AppText(_actionLabel(l10n)),
    );
  }

  String _actionLabel(AppLocalizations l10n) {
    return switch (entry.action) {
      'catalog.category.save' => l10n.auditActionCategorySaved,
      'products.save' => l10n.auditActionProductSaved,
      'payment_methods.save' => l10n.auditActionPaymentMethodSaved,
      'tables.save' => l10n.auditActionTableSaved,
      'sales.void' => l10n.auditActionSaleVoided,
      'cash.open' => l10n.auditActionCashOpened,
      'cash.close' => l10n.auditActionCashClosed,
      'expenses.category.save' => l10n.auditActionExpenseCategorySaved,
      'expenses.category.delete' => l10n.auditActionExpenseCategoryDeleted,
      'expenses.save' => l10n.auditActionExpenseSaved,
      'settings.save' => l10n.auditActionSettingsSaved,
      'roles.save' => l10n.auditActionRoleSaved,
      'users.save' => l10n.auditActionUserSaved,
      _ => entry.action,
    };
  }

  String _detailsLabel(AppLocalizations l10n) {
    return entry.details.entries
        .map((detail) => _detailLabel(l10n, detail.key, detail.value))
        .where((detail) => detail.isNotEmpty)
        .join(' - ');
  }

  String _detailLabel(AppLocalizations l10n, String key, Object? value) {
    if (value == null) return '';

    final label = _detailKeyLabel(l10n, key);
    if (label.isEmpty) return '';

    final text = _detailValueLabel(l10n, key, value);

    return '$label: $text';
  }

  String _detailKeyLabel(AppLocalizations l10n, String key) {
    return switch (key) {
      'name' => l10n.nameField,
      'reason' => l10n.auditDetailReason,
      'amountInCents' => l10n.amountInCentsField,
      'openingCashInCents' => l10n.cashOpeningAmount,
      'physicalClosingCashInCents' => l10n.cashPhysicalAmount,
      'description' => l10n.descriptionField,
      'businessName' => l10n.businessNameField,
      'invoicePrefix' => l10n.invoicePrefixField,
      'email' => l10n.emailField,
      'status' => l10n.auditDetailStatus,
      'isActive' => l10n.activeField,
      'isAvailableInPos' => l10n.availableInPosField,
      'requiresReference' => l10n.requiresReference,
      'affectsCashRegister' => l10n.cashAffectsRegister,
      'optionGroupCount' => l10n.auditDetailOptionGroups,
      'permissionCount' => l10n.auditDetailPermissions,
      'roleId' || 'categoryId' || 'parentId' => '',
      _ => key,
    };
  }

  String _detailValueLabel(
    AppLocalizations l10n,
    String key,
    Object value,
  ) {
    if (key.endsWith('InCents') || key == 'amountInCents') {
      return MoneyFormatter.format(_asInt(value));
    }

    if (key == 'isActive' && value is bool) {
      return value ? l10n.activeStatus : l10n.inactiveStatus;
    }

    if (value is bool) {
      return value ? l10n.yesLabel : l10n.noLabel;
    }

    return value.toString();
  }

  int _asInt(Object value) {
    if (value is int) return value;
    if (value is num) return value.round();

    return int.tryParse(value.toString()) ?? 0;
  }
}
