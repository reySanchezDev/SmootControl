import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/attendance/presentation/pages/attendance_employee_selection.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';

void main() {
  const active = Employee(id: 'active-1', fullName: 'Active employee');
  const inactive = Employee(
    id: 'inactive-2',
    fullName: 'Former employee',
    isActive: false,
  );

  test('active employee is available when editing and creating', () {
    final employees = [active, inactive];
    expect(AttendanceEmployeeSelection.forCreation(employees), [active]);
    expect(
      AttendanceEmployeeSelection.forEditing(employees, active.id),
      [active],
    );
    expect(
      AttendanceEmployeeSelection.canEdit(employees, active.id),
      isTrue,
    );
  });

  test('inactive historical employee remains selectable for their mark', () {
    final employees = [active, inactive];
    expect(
      AttendanceEmployeeSelection.forEditing(employees, inactive.id),
      [active, inactive],
    );
    expect(
      AttendanceEmployeeSelection.canEdit(employees, inactive.id),
      isTrue,
    );
    expect(
      AttendanceEmployeeSelection.forCreation(employees),
      isNot(contains(inactive)),
    );
  });

  test('unknown employee ID cannot be silently reassigned', () {
    final employees = [active, inactive];
    expect(
      AttendanceEmployeeSelection.forEditing(employees, 'missing-id'),
      isNull,
    );
    expect(
      AttendanceEmployeeSelection.canEdit(employees, 'missing-id'),
      isFalse,
    );
  });

  test('empty catalog cannot open editor or create a mark', () {
    expect(AttendanceEmployeeSelection.forCreation([]), isEmpty);
    expect(
      AttendanceEmployeeSelection.forEditing([], 'missing-id'),
      isNull,
    );
    expect(
      AttendanceEmployeeSelection.canEdit([], 'missing-id'),
      isFalse,
    );
  });
}
