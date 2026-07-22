import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/attendance/domain/entities/attendance_entry.dart';
import 'package:smoo_control/features/attendance/domain/repositories/i_attendance_repository.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';
import 'package:smoo_control/features/staff/domain/repositories/i_staff_repository.dart';

part 'attendance_admin_widgets_part.dart';

/// Admin page for attendance marks.
final class AttendanceAdminPage extends StatefulWidget {
  /// Creates the attendance admin page.
  const AttendanceAdminPage({this.readOnly = false, super.key});

  /// Whether this page is rendered as a report only.
  final bool readOnly;

  @override
  State<AttendanceAdminPage> createState() => _AttendanceAdminPageState();
}

class _AttendanceAdminPageState extends State<AttendanceAdminPage> {
  final IAttendanceRepository _attendanceRepository =
      serviceLocator<IAttendanceRepository>();
  final IStaffRepository _staffRepository = serviceLocator<IStaffRepository>();
  late DateTime _from;
  late DateTime _to;
  String? _status;
  List<Employee> _employees = const [];
  List<AttendanceEntry>? _entries;
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
      actions: [
        if (!widget.readOnly)
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _employees.isEmpty ? null : _openEditor,
            tooltip: 'Crear marcada',
          ),
      ],
      title: widget.readOnly ? 'Reporte de marcadas' : 'Marcadas',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AttendanceFilters(
            from: _from,
            onFrom: () => _pickDate(isFrom: true),
            onReload: _load,
            onStatus: (value) => setState(() => _status = value),
            status: _status,
            to: _to,
            onTo: () => _pickDate(isFrom: false),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            AppEmptyState(
              icon: Icons.error_outline,
              message: _error!,
              title: 'Marcadas',
            )
          else if (_entries == null)
            const AppLoadingPage()
          else if (_entries!.isEmpty)
            const AppEmptyState(
              icon: Icons.schedule_outlined,
              message: 'No hay marcadas para el filtro seleccionado.',
              title: 'Sin marcadas',
            )
          else
            for (final entry in _entries!)
              _AttendanceEntryCard(
                entry: entry,
                onEdit: widget.readOnly ? null : () async => _openEditor(entry),
                onVoid: widget.readOnly ? null : () => _voidEntry(entry),
              ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _entries = null;
      _error = null;
    });
    final employees = await _staffRepository.getEmployees();
    final entries = await _attendanceRepository.getRemoteEntries(
      from: _from,
      to: _to,
      status: _status,
    );
    if (!mounted) return;
    switch ((employees, entries)) {
      case (AppSuccess(value: final staff), AppSuccess(value: final marks)):
        setState(() {
          _employees = staff.where((item) => item.isActive).toList();
          _entries = marks;
        });
      case (AppFailureResult(error: final error), _):
        setState(() => _error = error.message);
      case (_, AppFailureResult(error: final error)):
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

  Future<void> _openEditor([AttendanceEntry? entry]) async {
    final saved = await showDialog<AttendanceEntry>(
      context: context,
      builder: (_) => _AttendanceEditorDialog(
        employees: _employees,
        entry: entry,
      ),
    );
    if (saved == null || !mounted) return;
    final result = await _attendanceRepository.saveRemoteEntry(saved);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marcada guardada.')),
        );
        await _load();
      case AppFailureResult(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
    }
  }

  Future<void> _voidEntry(AttendanceEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar marcada'),
        content: Text(
          'Se eliminara permanentemente la marcada de '
          '${entry.employeeName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final result = await _attendanceRepository.voidRemoteEntry(entry.id);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marcada eliminada.')),
        );
        await _load();
      case AppFailureResult(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
    }
  }
}
