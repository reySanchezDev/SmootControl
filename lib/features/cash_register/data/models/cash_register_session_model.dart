import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/utils/business_date_formatter.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';

/// Data model for daily cash register sessions.
final class CashRegisterSessionModel extends Equatable {
  /// Creates a cash register session model.
  const CashRegisterSessionModel({
    required this.id,
    required this.cashierId,
    required this.businessDate,
    required this.openingCashInCents,
    required this.status,
    this.physicalClosingCashInCents,
  });

  /// Creates a model from a local Drift row.
  factory CashRegisterSessionModel.fromLocal(LocalCashRegisterSession row) {
    return CashRegisterSessionModel(
      id: row.id,
      cashierId: row.cashierId,
      businessDate: BusinessDateFormatter.parse(row.businessDate),
      openingCashInCents: row.openingCashInCents,
      physicalClosingCashInCents: row.physicalClosingCashInCents,
      status: _statusFromText(row.status),
    );
  }

  /// Creates a model from a domain entity.
  factory CashRegisterSessionModel.fromEntity(CashRegisterSession entity) {
    return CashRegisterSessionModel(
      id: entity.id,
      cashierId: entity.cashierId,
      businessDate: entity.businessDate,
      openingCashInCents: entity.openingCashInCents,
      physicalClosingCashInCents: entity.physicalClosingCashInCents,
      status: entity.status,
    );
  }

  /// Unique session identifier.
  final String id;

  /// Cashier user identifier.
  final String cashierId;

  /// Business date.
  final DateTime businessDate;

  /// Starting cash amount.
  final int openingCashInCents;

  /// Physical cash counted at closing.
  final int? physicalClosingCashInCents;

  /// Current session status.
  final CashRegisterStatus status;

  /// Database value for business date.
  String get businessDateValue => BusinessDateFormatter.format(businessDate);

  /// Database value for status.
  String get statusValue => status.name;

  /// Converts this model to a domain entity.
  CashRegisterSession toEntity() {
    return CashRegisterSession(
      id: id,
      cashierId: cashierId,
      businessDate: businessDate,
      openingCashInCents: openingCashInCents,
      physicalClosingCashInCents: physicalClosingCashInCents,
      status: status,
    );
  }

  static CashRegisterStatus _statusFromText(String value) {
    return CashRegisterStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => CashRegisterStatus.open,
    );
  }

  @override
  List<Object?> get props => [
    id,
    cashierId,
    businessDate,
    openingCashInCents,
    physicalClosingCashInCents,
    status,
  ];
}
