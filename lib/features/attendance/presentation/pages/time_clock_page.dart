import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/attendance/domain/entities/attendance_entry.dart';
import 'package:smoo_control/features/attendance/domain/repositories/i_attendance_repository.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';

part 'time_clock_widgets_part.dart';

/// Standalone attendance marker page.
final class TimeClockPage extends StatefulWidget {
  /// Creates the time-clock page.
  const TimeClockPage({super.key});

  @override
  State<TimeClockPage> createState() => _TimeClockPageState();
}

class _TimeClockPageState extends State<TimeClockPage> {
  late Future<List<Employee>> _future;
  IAttendanceRepository get _repository =>
      serviceLocator<IAttendanceRepository>();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _loadEmployees();
  }

  Future<List<Employee>> _loadEmployees() async {
    final result = await _repository.getClockEmployees();
    return switch (result) {
      AppSuccess(:final value) => value,
      AppFailureResult(:final error) => throw StateError(error.message),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Marcador',
      body: FutureBuilder<List<Employee>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppEmptyState(
              icon: Icons.error_outline,
              message: snapshot.error.toString(),
              title: 'Marcador',
            );
          }
          if (!snapshot.hasData) return const AppLoadingPage();
          final employees = snapshot.requireData;
          if (employees.isEmpty) {
            return const AppEmptyState(
              icon: Icons.people_outline,
              title: 'Sin personal',
              message: 'Sin empleados activos sincronizados.',
            );
          }
          return _EmployeeClockGrid(
            employees: employees,
            onSelected: _selectEmployee,
          );
        },
      ),
    );
  }

  Future<void> _selectEmployee(Employee employee) async {
    final openResult = await _repository.getOpenEntry(employee.id);
    if (!mounted) return;
    final todayEntry = switch (openResult) {
      AppSuccess(:final value) => value,
      AppFailureResult(:final error) => throw StateError(error.message),
    };
    if (todayEntry != null && !todayEntry.isOpen) {
      await showAppMessageDialog(
        context: context,
        title: 'Jornada ya cerrada',
        message:
            '${employee.fullName} ya tiene entrada y salida registradas para '
            'hoy. Si necesitas corregirla, hacelo desde Admin > Marcadas.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ClockConfirmDialog(
        employee: employee,
        openEntry: todayEntry,
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = todayEntry == null
        ? await _repository.clockIn(employee)
        : await _repository.clockOut(todayEntry);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        await showAppMessageDialog(
          context: context,
          title: todayEntry == null
              ? 'Entrada registrada'
              : 'Salida registrada',
          message:
              'Marcada guardada correctamente. Si hay internet, ya fue '
              'enviada a Supabase; si no, queda pendiente para sincronizar.',
        );
        setState(_reload);
      case AppFailureResult(:final error):
        await showAppMessageDialog(
          context: context,
          title: 'No se pudo marcar',
          message: error.message,
        );
    }
  }
}
