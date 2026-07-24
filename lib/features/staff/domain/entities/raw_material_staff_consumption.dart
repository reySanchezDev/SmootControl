import 'package:equatable/equatable.dart';

/// Raw-material product available for employee consumption.
final class RawMaterialProductOption extends Equatable {
  /// Creates a raw-material option.
  const RawMaterialProductOption({
    required this.id,
    required this.name,
    required this.costInCents,
    this.purchaseUnitId,
    this.inventoryUnitId,
    this.recipeDefaultUnitId,
    this.inventoryDisplayUnitId,
    this.purchaseToInventoryFactor,
  });

  /// Product id.
  final String id;

  /// Product name.
  final String name;

  /// Current product cost.
  final int costInCents;

  /// Purchase unit id.
  final String? purchaseUnitId;

  /// Inventory base unit id.
  final String? inventoryUnitId;

  /// Recipe default unit id.
  final String? recipeDefaultUnitId;

  /// Preferred display/count unit id.
  final String? inventoryDisplayUnitId;

  /// Purchase to inventory conversion factor.
  final double? purchaseToInventoryFactor;

  @override
  List<Object?> get props => [
    id,
    name,
    costInCents,
    purchaseUnitId,
    inventoryUnitId,
    recipeDefaultUnitId,
    inventoryDisplayUnitId,
    purchaseToInventoryFactor,
  ];
}

/// Raw-material staff consumption header.
final class RawMaterialStaffConsumption extends Equatable {
  /// Creates a raw-material staff consumption.
  const RawMaterialStaffConsumption({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.consumedAt,
    required this.totalInCents,
    required this.lines,
    this.note,
    this.payrollRunId,
  });

  /// Consumption id.
  final String id;

  /// Employee id.
  final String employeeId;

  /// Employee name.
  final String employeeName;

  /// Consumption date and time.
  final DateTime consumedAt;

  /// Optional note.
  final String? note;

  /// Total amount charged to employee.
  final int totalInCents;

  /// Payroll run id when already deducted.
  final String? payrollRunId;

  /// Detail lines.
  final List<RawMaterialStaffConsumptionLine> lines;

  @override
  List<Object?> get props => [
    id,
    employeeId,
    employeeName,
    consumedAt,
    note,
    totalInCents,
    payrollRunId,
    lines,
  ];
}

/// Raw-material staff consumption line.
final class RawMaterialStaffConsumptionLine extends Equatable {
  /// Creates a raw-material staff consumption line.
  const RawMaterialStaffConsumptionLine({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceInCents,
    required this.subtotalInCents,
    this.inventoryQuantity,
    this.unitId,
    this.unitName,
    this.unitCode,
  });

  /// Line id.
  final String id;

  /// Product id.
  final String productId;

  /// Product name snapshot.
  final String productName;

  /// Quantity entered by the user.
  final double quantity;

  /// Quantity converted to inventory base.
  final double? inventoryQuantity;

  /// Unit id used by the user.
  final String? unitId;

  /// Unit name snapshot.
  final String? unitName;

  /// Unit code snapshot.
  final String? unitCode;

  /// Unit price charged to employee.
  final int unitPriceInCents;

  /// Line subtotal.
  final int subtotalInCents;

  @override
  List<Object?> get props => [
    id,
    productId,
    productName,
    quantity,
    inventoryQuantity,
    unitId,
    unitName,
    unitCode,
    unitPriceInCents,
    subtotalInCents,
  ];
}
