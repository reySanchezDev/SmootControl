import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/attendance/domain/entities/vacation_request.dart';
import 'package:smoo_control/features/attendance/domain/repositories/i_attendance_repository.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';
import 'package:smoo_control/features/staff/domain/repositories/i_staff_repository.dart';
import 'package:uuid/uuid.dart';

part 'vacation_requests_widgets_part.dart';
part 'vacation_requests_form_part.dart';

/// Backoffice inbox and registry for employee vacation days.
final class VacationRequestsPage extends StatefulWidget {
  /// Creates the page.
  const VacationRequestsPage({super.key});

  @override
  State<VacationRequestsPage> createState() => _VacationRequestsPageState();
}

class _VacationRequestsPageState extends State<VacationRequestsPage> {
  final IAttendanceRepository _attendance =
      serviceLocator<IAttendanceRepository>();
  final IStaffRepository _staff = serviceLocator<IStaffRepository>();
  late DateTime _from;
  late DateTime _to;
  List<Employee> _employees = const [];
  List<VacationRequest>? _items;
  String? _employeeId;
  String? _status;
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
      title: 'Vacaciones',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _employees.isEmpty ? null : () => unawaited(_create()),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _VacationFilters(
            from: _from,
            to: _to,
            employees: _employees,
            employeeId: _employeeId,
            status: _status,
            onFrom: () => _pickDate(isFrom: true),
            onTo: () => _pickDate(isFrom: false),
            onEmployee: (value) => setState(() => _employeeId = value),
            onStatus: (value) => setState(() => _status = value),
            onReload: _load,
          ),
          const SizedBox(height: 12),
          if (_error != null)
            AppEmptyState(
              icon: Icons.error_outline,
              title: 'Vacaciones',
              message: _error!,
            )
          else if (_items == null)
            const AppLoadingPage()
          else if (_items!.isEmpty)
            const AppEmptyState(
              icon: Icons.beach_access_outlined,
              title: 'Sin registros',
              message: 'No hay vacaciones en el rango seleccionado.',
            )
          else
            for (final item in _items!)
              _VacationCard(item: item, onAction: _act),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    final employeesResult = await _staff.getEmployees();
    final requestsResult = await _attendance.getVacationRequests(
      from: _from,
      to: _to,
      employeeId: _employeeId,
      status: _status,
    );
    if (!mounted) return;
    switch ((employeesResult, requestsResult)) {
      case (AppSuccess(value: final employees), AppSuccess(value: final rows)):
        setState(() {
          _employees = employees
              .where((employee) => employee.isActive)
              .toList();
          _items = rows;
        });
      case (_, AppFailureResult(:final error)):
        setState(() => _error = error.message);
      case (AppFailureResult(:final error), _):
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

  Future<void> _create() async {
    final request = await showDialog<VacationRequest>(
      context: context,
      builder: (_) => _VacationFormDialog(employees: _employees),
    );
    if (request == null || !mounted) return;
    await _save(request);
  }

  Future<void> _save(VacationRequest request) async {
    final result = await _attendance.saveVacationRequest(request);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        await showAppMessageDialog(
          context: context,
          title: 'Vacaciones guardadas',
          message: 'El registro fue guardado correctamente.',
        );
        await _load();
      case AppFailureResult(:final error):
        await showAppMessageDialog(
          context: context,
          title: 'No se pudo guardar',
          message: error.message,
        );
    }
  }

  Future<void> _act(VacationRequest item, String action) async {
    final result = switch (action) {
      'approved' || 'rejected' => await _attendance.setVacationStatus(
        item.id,
        action,
      ),
      'delete' => await _attendance.deleteVacationRequest(item.id),
      _ => const AppSuccess<void>(null),
    };
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        await showAppMessageDialog(
          context: context,
          title: 'Vacaciones actualizadas',
          message: 'La accion se aplico correctamente.',
        );
        await _load();
      case AppFailureResult(:final error):
        await showAppMessageDialog(
          context: context,
          title: 'No se pudo completar',
          message: error.message,
        );
    }
  }
}
