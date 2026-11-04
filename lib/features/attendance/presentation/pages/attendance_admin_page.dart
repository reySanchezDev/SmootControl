import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_form_standards.dart';
import 'package:smoo_control/core/design_system/backoffice_selection_toolbar.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/attendance/domain/entities/attendance_entry.dart';
import 'package:smoo_control/features/attendance/domain/repositories/i_attendance_repository.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';
import 'package:smoo_control/features/staff/domain/repositories/i_staff_repository.dart';

part 'attendance_admin_widgets_part.dart';
part 'attendance_admin_table_part.dart';

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
      title: widget.readOnly ? 'Reporte de marcadas' : 'Marcadas',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _AttendanceFilters(
                from: _from,
                to: _to,
                onFrom: () => _pickDate(isFrom: true),
                onTo: () => _pickDate(isFrom: false),
                onStatus: (value) => setState(() => _status = value),
                status: _status,
                onReload: _load,
              ),
            ),
          ),
          Expanded(
            child: _error != null
                ? AppEmptyState(
                    icon: Icons.error_outline,
                    message: _error!,
                    title: 'Marcadas',
                  )
                : _entries == null
                    ? const AppLoadingPage()
                    : _AttendanceEntriesTable(
                        items: _entries!,
                        readOnly: widget.readOnly,
                        onCreate: widget.readOnly
                            ? null
                            : () => unawaited(_openEditor()),
                        createEnabled: _employees.isNotEmpty,
                        onEdit: (entry) => unawaited(_openEditor(entry)),
                        onVoid: (entry) => unawaited(_voidEntry(entry)),
                      ),
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
        await showAppMessageDialog(
          context: context,
          title: 'Marcada guardada',
          message: 'La marcada se guardó correctamente.',
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

  Future<void> _voidEntry(AttendanceEntry entry) async {
    final confirm = await showAppConfirmationDialog(
      context,
      title: 'Eliminar marcada',
      message: 'Se eliminará permanentemente la marcada de '
          '${entry.employeeName}.',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Cancelar',
      destructive: true,
    );
    if (!confirm || !mounted) return;
    final result = await _attendanceRepository.voidRemoteEntry(entry.id);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        await showAppMessageDialog(
          context: context,
          title: 'Marcada eliminada',
          message: 'El registro fue eliminado correctamente.',
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
