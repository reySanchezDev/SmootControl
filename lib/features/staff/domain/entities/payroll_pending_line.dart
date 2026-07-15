import 'package:equatable/equatable.dart';

/// Pending payroll amount for one employee and period.
final class PayrollPendingLine extends Equatable {
  /// Creates a pending payroll line.
  const PayrollPendingLine({
    required this.payrollRunId,
    required this.employeeId,
    required this.employeeName,
    required this.periodStart,
    required this.periodEnd,
    required this.periodLabel,
    required this.baseSalaryInCents,
    required this.consumptionInCents,
    required this.overtimeInCents,
    required this.salaryAdvanceDeductionInCents,
    required this.netPayInCents,
    required this.paidInCents,
    required this.balanceInCents,
  });

  /// Payroll run identifier.
  final String payrollRunId;

  /// Employee identifier.
  final String employeeId;

  /// Employee display name.
  final String employeeName;

  /// Period start date.
  final DateTime periodStart;

  /// Period end date.
  final DateTime periodEnd;

  /// Human-readable period label.
  final String periodLabel;

  /// Base salary in minor currency units.
  final int baseSalaryInCents;

  /// Staff consumption deducted in minor currency units.
  final int consumptionInCents;

  /// Overtime amount included in the line.
  final int overtimeInCents;

  /// Salary advance deduction in minor currency units.
  final int salaryAdvanceDeductionInCents;

  /// Net payroll amount in minor currency units.
  final int netPayInCents;

  /// Already paid amount in minor currency units.
  final int paidInCents;

  /// Pending balance in minor currency units.
  final int balanceInCents;

  @override
  List<Object?> get props => [
    payrollRunId,
    employeeId,
    employeeName,
    periodStart,
    periodEnd,
    periodLabel,
    baseSalaryInCents,
    consumptionInCents,
    overtimeInCents,
    salaryAdvanceDeductionInCents,
    netPayInCents,
    paidInCents,
    balanceInCents,
  ];
}
