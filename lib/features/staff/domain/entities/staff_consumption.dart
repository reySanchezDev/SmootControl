import 'package:equatable/equatable.dart';

/// Staff consumption header.
final class StaffConsumption extends Equatable {
  /// Creates a staff consumption header.
  const StaffConsumption({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.receiptLabel,
    required this.totalInCents,
    required this.createdAt,
    this.payrollRunId,
  });

  /// Sale identifier.
  final String id;

  /// Employee identifier.
  final String employeeId;

  /// Employee name.
  final String employeeName;

  /// Internal receipt label.
  final String receiptLabel;

  /// Total amount.
  final int totalInCents;

  /// Payroll run applied, if any.
  final String? payrollRunId;

  /// Creation date.
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    employeeId,
    employeeName,
    receiptLabel,
    totalInCents,
    payrollRunId,
    createdAt,
  ];
}

/// Staff consumption detail line.
final class StaffConsumptionItem extends Equatable {
  /// Creates an item.
  const StaffConsumptionItem({
    required this.productName,
    required this.quantity,
    required this.unitPriceInCents,
    required this.totalInCents,
    this.selectedOptionsLabel,
  });

  /// Product name.
  final String productName;

  /// Quantity.
  final int quantity;

  /// Unit price.
  final int unitPriceInCents;

  /// Total.
  final int totalInCents;

  /// Modifier label.
  final String? selectedOptionsLabel;

  @override
  List<Object?> get props => [
    productName,
    quantity,
    unitPriceInCents,
    totalInCents,
    selectedOptionsLabel,
  ];
}
