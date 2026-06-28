import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';

/// Data model for restaurant tables.
final class RestaurantTableModel extends Equatable {
  /// Creates a restaurant table model.
  const RestaurantTableModel({
    required this.id,
    required this.name,
    required this.status,
    required this.isActive,
    this.displayName,
  });

  /// Creates a model from a local Drift row.
  factory RestaurantTableModel.fromLocal(LocalRestaurantTable row) {
    return RestaurantTableModel(
      id: row.id,
      name: row.name,
      displayName: row.displayName,
      status: _statusFromText(row.status),
      isActive: row.isActive,
    );
  }

  /// Creates a model from a domain entity.
  factory RestaurantTableModel.fromEntity(RestaurantTable entity) {
    return RestaurantTableModel(
      id: entity.id,
      name: entity.name,
      displayName: entity.displayName,
      status: entity.status,
      isActive: entity.isActive,
    );
  }

  /// Unique table identifier.
  final String id;

  /// Internal table name.
  final String name;

  /// Temporary operational name.
  final String? displayName;

  /// Current table state.
  final RestaurantTableStatus status;

  /// Whether the table can be used.
  final bool isActive;

  /// Database value for the current status.
  String get statusValue => status.name;

  /// Converts this model to a domain entity.
  RestaurantTable toEntity() {
    return RestaurantTable(
      id: id,
      name: name,
      displayName: displayName,
      status: status,
      isActive: isActive,
    );
  }

  static RestaurantTableStatus _statusFromText(String value) {
    return RestaurantTableStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => RestaurantTableStatus.available,
    );
  }

  @override
  List<Object?> get props => [id, name, displayName, status, isActive];
}
