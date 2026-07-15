part of 'supabase_staff_admin_repository.dart';

mixin _SupabaseStaffOvertimeMixin on _SupabaseStaffAdminRepositoryBase {
  Future<AppResult<List<EmployeeOvertimeEntry>>> getOvertimeEntries() {
    return _guard(
      'overtime_entries_read_failed',
      'No se pudieron leer horas extras.',
      () async {
        final rows = await _rpcRows('app_get_employee_overtime_entries', {
          'p_restaurant_id': _restaurantId,
        });
        return rows.map(_overtimeFromRow).toList();
      },
    );
  }

  Future<AppResult<EmployeeOvertimeEntry>> saveOvertimeEntry(
    EmployeeOvertimeEntry entry,
  ) {
    return _guard(
      'overtime_entry_save_failed',
      'No se pudo guardar la hora extra.',
      () async {
        await _rpc('app_save_employee_overtime_entry', {
          'p_restaurant_id': _restaurantId,
          'p_payload': {
            'id': entry.id,
            'employee_id': entry.employeeId,
            'worked_date': _dateOnly(entry.workedDate),
            'hours': entry.hours,
            'note': entry.note,
          },
        });
        return entry;
      },
    );
  }

  Future<AppResult<void>> deleteOvertimeEntry(String overtimeId) {
    return _guard(
      'overtime_entry_delete_failed',
      'No se pudo eliminar la hora extra.',
      () async {
        await _rpc('app_delete_employee_overtime_entry', {
          'p_restaurant_id': _restaurantId,
          'p_overtime_id': overtimeId,
        });
      },
    );
  }
}
