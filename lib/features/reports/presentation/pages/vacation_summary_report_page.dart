import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/attendance/domain/entities/vacation_summary.dart';
import 'package:smoo_control/features/attendance/domain/repositories/i_attendance_repository.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';
import 'package:smoo_control/features/staff/domain/repositories/i_staff_repository.dart';

/// Consolidated vacation balance report.
final class VacationSummaryReportPage extends StatefulWidget {
  /// Creates the report page.
  const VacationSummaryReportPage({super.key});

  @override
  State<VacationSummaryReportPage> createState() =>
      _VacationSummaryReportPageState();
}

class _VacationSummaryReportPageState extends State<VacationSummaryReportPage> {
  final IAttendanceRepository _attendance =
      serviceLocator<IAttendanceRepository>();
  final IStaffRepository _staff = serviceLocator<IStaffRepository>();
  DateTime _asOf = DateTime.now();
  List<Employee> _employees = const [];
  List<VacationSummary>? _rows;
  String? _employeeId;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Reporte de vacaciones',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.calendar_today_outlined),
                    label: Text('Al ${_fmt(_asOf)}'),
                    onPressed: _pickDate,
                  ),
                  DropdownButton<String?>(
                    value: _employeeId,
                    hint: const Text('Empleado'),
                    items: [
                      const DropdownMenuItem(child: Text('Todos')),
                      for (final employee in _employees)
                        DropdownMenuItem(
                          value: employee.id,
                          child: Text(employee.fullName),
                        ),
                    ],
                    onChanged: (value) => setState(() => _employeeId = value),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recargar'),
                    onPressed: _load,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            AppEmptyState(
              icon: Icons.error_outline,
              title: 'Vacaciones',
              message: _error!,
            )
          else if (_rows == null)
            const AppLoadingPage()
          else if (_rows!.isEmpty)
            const AppEmptyState(
              icon: Icons.beach_access_outlined,
              title: 'Sin datos',
              message: 'No hay empleados para el filtro seleccionado.',
            )
          else
            for (final row in _rows!) _SummaryCard(row: row),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _rows = null;
      _error = null;
    });
    final employeesResult = await _staff.getEmployees();
    final summaryResult = await _attendance.getVacationSummary(
      asOf: _asOf,
      employeeId: _employeeId,
    );
    if (!mounted) return;
    switch ((employeesResult, summaryResult)) {
      case (AppSuccess(value: final employees), AppSuccess(value: final rows)):
        setState(() {
          _employees = employees.where((item) => item.isActive).toList();
          _rows = rows;
        });
      case (_, AppFailureResult(:final error)):
        setState(() => _error = error.message);
      case (AppFailureResult(:final error), _):
        setState(() => _error = error.message);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      initialDate: _asOf,
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _asOf = picked);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.row});

  final VacationSummary row;

  @override
  Widget build(BuildContext context) {
    final scheduled = row.scheduledDays > 0
        ? '${row.scheduledDays.toStringAsFixed(2)} dias '
              '(${_fmt(row.scheduledFrom!)} - ${_fmt(row.scheduledTo!)})'
        : '0.00 dias';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(row.employeeName, variant: AppTextVariant.titleMedium),
            const SizedBox(height: 8),
            _Row(label: 'Fecha de inicio', value: _fmt(row.startDate)),
            _Row(label: 'Dias acumulados', value: _days(row.accumulatedDays)),
            _Row(label: 'Dias tomados', value: _days(row.takenDays)),
            _Row(label: 'Dias programados', value: scheduled),
            const Divider(),
            _Row(label: 'Saldo actual', value: _days(row.currentBalance)),
            _Row(
              label: 'Saldo proyectado',
              value: _days(row.projectedBalance),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AppText(label)),
        Flexible(child: AppText(value, textAlign: TextAlign.end)),
      ],
    );
  }
}

String _days(double value) => '${value.toStringAsFixed(2)} dias';

String _fmt(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
