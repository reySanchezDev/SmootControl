import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/tables/domain/entities/table_account.dart';

/// Data model for named table accounts.
final class TableAccountModel extends Equatable {
  /// Creates a table account model.
  const TableAccountModel({
    required this.id,
    required this.tableId,
    required this.name,
    required this.status,
  });

  /// Creates a model from a local Drift row.
  factory TableAccountModel.fromLocal(LocalTableAccount row) {
    return TableAccountModel(
      id: row.id,
      tableId: row.tableId,
      name: row.name,
      status: _statusFromText(row.status),
    );
  }

  /// Creates a model from a domain entity.
  factory TableAccountModel.fromEntity(TableAccount entity) {
    return TableAccountModel(
      id: entity.id,
      tableId: entity.tableId,
      name: entity.name,
      status: entity.status,
    );
  }

  /// Unique account identifier.
  final String id;

  /// Original table identifier.
  final String tableId;

  /// Visible account or invoice name.
  final String name;

  /// Current account state.
  final TableAccountStatus status;

  /// Database value for status.
  String get statusValue => status.name;

  /// Converts this model to a domain entity.
  TableAccount toEntity() {
    return TableAccount(
      id: id,
      tableId: tableId,
      name: name,
      status: status,
    );
  }

  static TableAccountStatus _statusFromText(String value) {
    return TableAccountStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TableAccountStatus.open,
    );
  }

  @override
  List<Object?> get props => [id, tableId, name, status];
}
