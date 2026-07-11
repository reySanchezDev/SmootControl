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
              'employee_number,position_id',
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
}
