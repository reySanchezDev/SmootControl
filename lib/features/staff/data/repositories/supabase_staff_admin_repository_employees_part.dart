part of 'supabase_staff_admin_repository.dart';

mixin _SupabaseStaffEmployeesMixin on _SupabaseStaffAdminRepositoryBase {
  Future<AppResult<List<Employee>>> getEmployees() {
    return _guard(
      'employees_read_failed',
      'No se pudo leer el personal.',
      () async {
        final rows = await _getRows('employees', {
          'restaurant_id': 'eq.$_restaurantId',
          'select':
              'id,code,full_name,position_name,base_salary,is_active,'
              'employee_number,position_id,photo_url,show_in_time_clock,'
              'work_shift_id,employee_work_shifts(name,start_time,end_time)',
          'order': 'full_name.asc',
        });
        return rows.map(_employeeFromRow).toList();
      },
    );
  }

  Future<AppResult<Employee>> saveEmployee(Employee employee) {
    return _guard(
      'employee_save_failed',
      'No se pudo guardar el empleado.',
      () async {
        final row = await _rpcRow('app_save_employee', {
          'p_restaurant_id': _restaurantId,
          'p_payload': {
            'id': employee.id,
            'full_name': employee.fullName,
            'position_id': employee.positionName,
            'base_salary': _money(employee.baseSalaryInCents),
            'is_active': employee.isActive,
            'photo_url': employee.photoUrl,
            'show_in_time_clock': employee.showInTimeClock,
            'work_shift_id': employee.workShiftId,
          },
        });
        return _employeeFromRow(row);
      },
    );
  }

  Future<AppResult<List<EmployeePosition>>> getPositions() {
    return _guard(
      'positions_read_failed',
      'No se pudieron leer los puestos.',
      () async {
        final rows = await _getRows('employee_positions', {
          'restaurant_id': 'eq.$_restaurantId',
          'select': 'id,name,display_order,is_active',
          'order': 'display_order.asc,name.asc',
        });
        return rows.map(_positionFromRow).toList();
      },
    );
  }

  Future<AppResult<EmployeePosition>> savePosition(EmployeePosition position) {
    return _guard(
      'position_save_failed',
      'No se pudo guardar el puesto.',
      () async {
        final row = await _rpcRow('app_save_employee_position', {
          'p_restaurant_id': _restaurantId,
          'p_payload': {
            'id': position.id,
            'name': position.name,
            'display_order': position.displayOrder,
            'is_active': position.isActive,
          },
        });
        return _positionFromRow(row);
      },
    );
  }

  Future<AppResult<List<EmployeeWorkShift>>> getWorkShifts() {
    return _guard(
      'work_shifts_read_failed',
      'No se pudieron leer los turnos.',
      () async {
        final rows = await _getRows('employee_work_shifts', {
          'restaurant_id': 'eq.$_restaurantId',
          'select': 'id,name,start_time,end_time,is_active',
          'order': 'name.asc',
        });
        return rows.map(_workShiftFromRow).toList();
      },
    );
  }

  Future<AppResult<EmployeeWorkShift>> saveWorkShift(EmployeeWorkShift shift) {
    return _guard(
      'work_shift_save_failed',
      'No se pudo guardar el turno.',
      () async {
        final row = await _rpcRow('app_save_employee_work_shift', {
          'p_restaurant_id': _restaurantId,
          'p_payload': {
            'id': shift.id,
            'name': shift.name,
            'start_time': shift.startTime,
            'end_time': shift.endTime,
            'is_active': shift.isActive,
          },
        });
        return _workShiftFromRow(row);
      },
    );
  }
}
