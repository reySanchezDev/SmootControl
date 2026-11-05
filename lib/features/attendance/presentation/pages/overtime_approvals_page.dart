import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/backoffice_action_feedback.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_selection_toolbar.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/attendance/domain/entities/overtime_candidate.dart';
import 'package:smoo_control/features/attendance/domain/repositories/i_attendance_repository.dart';

/// Approval inbox for overtime calculated from attendance.
final class OvertimeApprovalsPage extends StatefulWidget {
  /// Creates the overtime approval page.
  const OvertimeApprovalsPage({super.key});

  @override
  State<OvertimeApprovalsPage> createState() => _OvertimeApprovalsPageState();
}

class _OvertimeApprovalsPageState extends State<OvertimeApprovalsPage> {
  final IAttendanceRepository _repository =
      serviceLocator<IAttendanceRepository>();
  late DateTime _from;
  late DateTime _to;
  List<OvertimeCandidate>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month);
    _to = DateTime(now.year, now.month, now.day);
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Horas extra por autorizar',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_outlined),
                  label: Text('Desde ${_fmt(_from)}'),
                  onPressed: () => _pickDate(isFrom: true),
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_outlined),
                  label: Text('Hasta ${_fmt(_to)}'),
                  onPressed: () => _pickDate(isFrom: false),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recargar'),
                  onPressed: _load,
                ),
              ],
            ),
          ),
          Expanded(
            child: _error != null
                ? AppEmptyState(
                    icon: Icons.error_outline,
                    message: _error!,
                    title: 'Horas extra',
                  )
                : _items == null
                    ? const AppLoadingPage()
                    : BackofficeCollectionView<OvertimeCandidate>(
                        items: _items!,
                        rowKey: (item) => item.id,
                        rowLabel: (item) => item.employeeName,
                        selectionActions: [
                          BackofficeSelectionAction<OvertimeCandidate>(
                            label: 'Autorizar',
                            icon: Icons.check_outlined,
                            onPressed: (item) =>
                                unawaited(_act(item, approve: true)),
                          ),
                          BackofficeSelectionAction<OvertimeCandidate>(
                            label: 'Rechazar',
                            icon: Icons.close_outlined,
                            onPressed: (item) =>
                                unawaited(_act(item, approve: false)),
                          ),
                        ],
                        searchLabel: 'Buscar empleado o fecha',
                        searchTextFor: (item) =>
                            '${item.employeeName} ${_fmt(item.workedDate)}',
                        emptyTitle: 'Sin pendientes',
                        emptyMessage: 'No hay horas extra pendientes.',
                        compactBuilder: (context, item) => ListTile(
                          title: Text(item.employeeName),
                          subtitle: Text(
                            '${_fmt(item.workedDate)} · '
                            '${item.hours.toStringAsFixed(2)} horas',
                          ),
                          trailing: Text(
                            MoneyFormatter.format(item.totalInCents),
                          ),
                        ),
                        columns: [
                          BackofficeListColumn<OvertimeCandidate>(
                            label: 'Empleado',
                            width: 280,
                            compare: (a, b) =>
                                a.employeeName.compareTo(b.employeeName),
                            cell: (_, item) => Text(item.employeeName),
                          ),
                          BackofficeListColumn<OvertimeCandidate>(
                            label: 'Fecha',
                            width: 160,
                            compare: (a, b) =>
                                a.workedDate.compareTo(b.workedDate),
                            cell: (_, item) => Text(_fmt(item.workedDate)),
                          ),
                          BackofficeListColumn<OvertimeCandidate>(
                            label: 'Horas',
                            width: 130,
                            alignment: Alignment.centerRight,
                            compare: (a, b) => a.hours.compareTo(b.hours),
                            cell: (_, item) =>
                                Text(item.hours.toStringAsFixed(2)),
                          ),
                          BackofficeListColumn<OvertimeCandidate>(
                            label: 'Monto',
                            width: 170,
                            alignment: Alignment.centerRight,
                            compare: (a, b) =>
                                a.totalInCents.compareTo(b.totalInCents),
                            cell: (_, item) =>
                                Text(MoneyFormatter.format(item.totalInCents)),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    final result = await _repository.getOvertimeCandidates(
      from: _from,
      status: 'pending',
      to: _to,
    );
    if (!mounted) return;
    switch (result) {
      case AppSuccess(:final value):
        setState(() => _items = value);
      case AppFailureResult(:final error):
        setState(() => _error = error.message);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      initialDate: isFrom ? _from : _to,
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _act(OvertimeCandidate item, {required bool approve}) async {
    final result = approve
        ? await _repository.approveOvertimeCandidate(item.id)
        : await _repository.rejectOvertimeCandidate(item.id);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        BackofficeActionFeedback.show(
          context,
          outcome: BackofficeActionOutcome.success,
          message: approve ? 'Hora extra autorizada.' : 'Hora extra rechazada.',
        );
        await _load();
      case AppFailureResult(:final error):
        BackofficeActionFeedback.show(
          context,
          outcome: BackofficeActionOutcome.error,
          message: error.message,
        );
    }
  }
}

String _fmt(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
