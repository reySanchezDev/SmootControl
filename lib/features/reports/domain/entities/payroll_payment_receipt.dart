import 'package:equatable/equatable.dart';

/// Historical payroll payment receipt used by payroll reports.
final class PayrollPaymentReceipt extends Equatable {
  /// Creates a payroll payment receipt snapshot.
  const PayrollPaymentReceipt({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.positionName,
    required this.periodStart,
    required this.periodEnd,
    required this.periodLabel,
    required this.baseSalaryInCents,
    required this.overtimeInCents,
    required this.consumptionInCents,
    required this.advanceDeductionInCents,
    required this.netPayInCents,
    required this.paymentAmountInCents,
    required this.paidAmountAfterInCents,
    required this.balanceAfterInCents,
    required this.advanceBalanceAfterInCents,
    required this.consumptions,
    required this.overtimeEntries,
    required this.advances,
    required this.paidAt,
  });

  /// Receipt identifier.
  final String id;

  /// Employee identifier.
  final String employeeId;

  /// Employee display name.
  final String employeeName;

  /// Employee business code.
  final String employeeCode;

  /// Employee position name.
  final String positionName;

  /// Payroll period start.
  final DateTime periodStart;

  /// Payroll period end.
  final DateTime periodEnd;

  /// Human-readable payroll period.
  final String periodLabel;

  /// Salary used for this payment.
  final int baseSalaryInCents;

  /// Overtime paid in this receipt.
  final int overtimeInCents;

  /// Staff consumption deducted in this receipt.
  final int consumptionInCents;

  /// Salary advance applied in this receipt.
  final int advanceDeductionInCents;

  /// Net payroll amount for the line or payment snapshot.
  final int netPayInCents;

  /// Amount delivered to the employee in this receipt.
  final int paymentAmountInCents;

  /// Total paid in the payroll line after this receipt.
  final int paidAmountAfterInCents;

  /// Payroll line balance after this receipt.
  final int balanceAfterInCents;

  /// Employee salary advance balance after this receipt.
  final int advanceBalanceAfterInCents;

  /// Consumption details captured at payment time.
  final List<PayrollReceiptConsumption> consumptions;

  /// Overtime details captured at payment time.
  final List<PayrollReceiptOvertime> overtimeEntries;

  /// Salary advance details captured at payment time.
  final List<PayrollReceiptAdvance> advances;

  /// Payment timestamp.
  final DateTime paidAt;

  @override
  List<Object?> get props => [
    id,
    employeeId,
    employeeName,
    employeeCode,
    positionName,
    periodStart,
    periodEnd,
    periodLabel,
    baseSalaryInCents,
    overtimeInCents,
    consumptionInCents,
    advanceDeductionInCents,
    netPayInCents,
    paymentAmountInCents,
    paidAmountAfterInCents,
    balanceAfterInCents,
    advanceBalanceAfterInCents,
    consumptions,
    overtimeEntries,
    advances,
    paidAt,
  ];
}

/// Overtime entry paid through one payroll receipt.
final class PayrollReceiptOvertime extends Equatable {
  /// Creates an overtime receipt detail.
  const PayrollReceiptOvertime({
    required this.date,
    required this.hours,
    required this.hourRateInCents,
    required this.amountInCents,
    this.note,
  });

  /// Overtime work date.
  final DateTime date;

  /// Number of paid overtime hours.
  final double hours;

  /// Hour rate used for this entry.
  final int hourRateInCents;

  /// Paid amount for this entry.
  final int amountInCents;

  /// Optional note.
  final String? note;

  @override
  List<Object?> get props => [
    date,
    hours,
    hourRateInCents,
    amountInCents,
    note,
  ];
}

/// Staff consumption applied to one payroll payment receipt.
final class PayrollReceiptConsumption extends Equatable {
  /// Creates a consumption detail.
  const PayrollReceiptConsumption({
    required this.receipt,
    required this.date,
    required this.amountInCents,
  });

  /// Staff consumption receipt label.
  final String receipt;

  /// Consumption date.
  final DateTime date;

  /// Amount deducted.
  final int amountInCents;

  @override
  List<Object?> get props => [receipt, date, amountInCents];
}

/// Salary advance payment applied to one payroll receipt.
final class PayrollReceiptAdvance extends Equatable {
  /// Creates a salary advance detail.
  const PayrollReceiptAdvance({
    required this.deliveredAt,
    required this.originalAmountInCents,
    required this.appliedAmountInCents,
    required this.balanceAfterInCents,
  });

  /// Advance delivery date.
  final DateTime deliveredAt;

  /// Original salary advance amount.
  final int originalAmountInCents;

  /// Amount applied by this payroll receipt.
  final int appliedAmountInCents;

  /// Advance balance after this application.
  final int balanceAfterInCents;

  @override
  List<Object?> get props => [
    deliveredAt,
    originalAmountInCents,
    appliedAmountInCents,
    balanceAfterInCents,
  ];
}
