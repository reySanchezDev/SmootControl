import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/staff/domain/entities/business_rule.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';
import 'package:smoo_control/features/staff/domain/entities/employee_position.dart';
import 'package:smoo_control/features/staff/domain/entities/payroll_pending_line.dart';
import 'package:smoo_control/features/staff/domain/entities/salary_advance.dart';

/// Staff, business rule and payroll-facing repository contract.
abstract interface class IStaffRepository {
  /// Returns employees.
  Future<AppResult<List<Employee>>> getEmployees();

  /// Saves one employee.
  Future<AppResult<Employee>> saveEmployee(Employee employee);

  /// Returns employee positions.
  Future<AppResult<List<EmployeePosition>>> getPositions();

  /// Saves one employee position.
  Future<AppResult<EmployeePosition>> savePosition(EmployeePosition position);

  /// Returns business rules.
  Future<AppResult<List<BusinessRule>>> getBusinessRules();

  /// Saves one business rule.
  Future<AppResult<BusinessRule>> saveBusinessRule(BusinessRule rule);

  /// Returns salary advances.
  Future<AppResult<List<SalaryAdvance>>> getSalaryAdvances();

  /// Saves one salary advance.
  Future<AppResult<SalaryAdvance>> saveSalaryAdvance(SalaryAdvance advance);

  /// Returns pending payroll lines from previous periods.
  Future<AppResult<List<PayrollPendingLine>>> getPendingPayrollLines();

  /// Posts one employee payroll line.
  Future<AppResult<void>> postPayrollEmployee({
    required String employeeId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required int baseSalaryInCents,
    required int consumptionInCents,
    required int salaryAdvanceDeductionInCents,
    required int paymentAmountInCents,
  });
}
