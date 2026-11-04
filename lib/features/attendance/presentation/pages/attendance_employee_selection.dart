import 'package:smoo_control/features/staff/domain/entities/employee.dart';

/// Chooses real administrative employees for attendance editing and creation.
///
/// No employee is synthesized or substituted when a historical ID is missing.
abstract final class AttendanceEmployeeSelection {
  /// Active employees eligible for a new administrative attendance entry.
  static List<Employee> forCreation(List<Employee> employees) =>
      employees.where((employee) => employee.isActive).toList();

  /// Returns null when the original employee ID cannot be resolved.
  ///
  /// Editing preserves the original employee even when they are inactive.
  /// Active employees remain available in the original employee selector.
  static List<Employee>? forEditing(
    List<Employee> employees,
    String employeeId,
  ) {
    Employee? original;
    for (final employee in employees) {
      if (employee.id == employeeId) {
        original = employee;
        break;
      }
    }
    if (original == null) return null;

    final active = forCreation(employees);
    if (original.isActive) return active;
    return [...active, original];
  }

  /// Whether editing can resolve the actual employee by stable ID.
  static bool canEdit(List<Employee> employees, String employeeId) =>
      employees.any((employee) => employee.id == employeeId);
}
