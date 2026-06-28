import 'package:equatable/equatable.dart';

/// Current lifecycle state of a named table account.
enum TableAccountStatus {
  /// Account is still open.
  open,

  /// Account was invoiced.
  invoiced,

  /// Account was voided.
  voided,
}

/// Named account that belongs to a restaurant table.
final class TableAccount extends Equatable {
  /// Creates a table account.
  const TableAccount({
    required this.id,
    required this.tableId,
    required this.name,
    required this.status,
  });

  /// Unique account identifier.
  final String id;

  /// Original table identifier.
  final String tableId;

  /// Visible account or invoice name.
  final String name;

  /// Current account state.
  final TableAccountStatus status;

  @override
  List<Object?> get props => [id, tableId, name, status];
}
