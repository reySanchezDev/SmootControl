import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_selection_toolbar.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/presentation/bloc/audit_log_bloc.dart';
import 'package:smoo_control/features/audit/presentation/bloc/audit_log_event.dart';
import 'package:smoo_control/features/audit/presentation/bloc/audit_log_state.dart';
import 'package:smoo_control/features/audit/presentation/widgets/audit_log_tile.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Local audit log inspection page.
class AuditLogPage extends StatelessWidget {
  /// Creates the audit log page.
  const AuditLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final l10n = AppLocalizations.of(context);

    return BlocProvider(
      create: (_) =>
          serviceLocator<AuditLogBloc>()..add(AuditLogDateRequested(today)),
      child: AppPageScaffold(
        title: l10n.moduleAudit,
        body: BlocBuilder<AuditLogBloc, AuditLogState>(
          builder: (context, state) {
            return switch (state) {
              AuditLogInitial() || AuditLogLoading() => const AppLoadingPage(),
              AuditLogFailure(:final failure) => AppEmptyState(
                icon: Icons.error_outline,
                message: failure.message,
                title: l10n.moduleAudit,
              ),
              AuditLogLoaded(:final date, :final entries) => _AuditLogContent(
                date: date,
                entries: entries,
              ),
            };
          },
        ),
      ),
    );
  }
}

class _AuditLogContent extends StatelessWidget {
  const _AuditLogContent({
    required this.date,
    required this.entries,
  });

  final DateTime date;
  final List<AuditLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(DateFormat.yMMMd('es').format(date)),
              onPressed: () => _selectDate(context),
            ),
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: AppEmptyState(
                    icon: Icons.manage_search_outlined,
                    message: l10n.emptyAuditMessage,
                    title: l10n.emptyAuditTitle,
                  ),
                )
              : BackofficeCollectionView<AuditLogEntry>(
                  items: entries,
                  rowKey: (entry) => entry.id,
                  rowLabel: (entry) => entry.entityName,
                  selectionActions: [
                    BackofficeSelectionAction<AuditLogEntry>(
                      label: 'Ver detalle',
                      icon: Icons.visibility_outlined,
                      onPressed: (entry) => _showEntryDetail(context, entry),
                    ),
                  ],
                  searchLabel: 'Buscar acción, entidad o detalle',
                  searchTextFor: _searchText,
                  emptyTitle: l10n.emptySearchTitle,
                  emptyMessage: l10n.emptySearchMessage,
                  compactBuilder: (_, entry) => AuditLogTile(entry: entry),
                  columns: [
                    BackofficeListColumn(
                      label: 'Fecha y hora',
                      width: 190,
                      alignment: Alignment.center,
                      compare: (a, b) => a.occurredAt.compareTo(b.occurredAt),
                      cell: (_, entry) => Text(
                        DateFormat(
                          'dd/MM/yyyy HH:mm',
                          'es',
                        ).format(entry.occurredAt.toLocal()),
                      ),
                    ),
                    BackofficeListColumn(
                      label: 'Acción',
                      width: 310,
                      compare: (a, b) => auditActionLabel(
                        l10n,
                        a.action,
                      ).compareTo(auditActionLabel(l10n, b.action)),
                      cell: (_, entry) => Text(
                        auditActionLabel(l10n, entry.action),
                        softWrap: true,
                      ),
                    ),
                    BackofficeListColumn(
                      label: 'Entidad',
                      width: 235,
                      compare: (a, b) => a.entityName.compareTo(b.entityName),
                      cell: (_, entry) =>
                          Text(entry.entityName, softWrap: true),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  void _showEntryDetail(BuildContext context, AuditLogEntry entry) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Detalle de auditoría'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: AuditLogTile(entry: entry),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  String _searchText(AuditLogEntry entry) {
    return [
      entry.action,
      entry.entityName,
      DateFormat('dd/MM/yyyy HH:mm', 'es').format(entry.occurredAt.toLocal()),
      for (final detail in entry.details.entries)
        '${detail.key} ${detail.value}',
    ].join(' ');
  }

  Future<void> _selectDate(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      initialDate: date,
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected != null && context.mounted) {
      context.read<AuditLogBloc>().add(AuditLogDateRequested(selected));
    }
  }
}
