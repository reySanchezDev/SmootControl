import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';

/// Base event for tables state management.
sealed class TablesEvent extends Equatable {
  /// Creates a tables event.
  const TablesEvent();

  @override
  List<Object?> get props => [];
}

/// Loads restaurant tables.
final class TablesLoadRequested extends TablesEvent {
  /// Creates a load event.
  const TablesLoadRequested();
}

/// Saves a restaurant table.
final class TableSaved extends TablesEvent {
  /// Creates a save event.
  const TableSaved(this.table);

  /// Table to persist.
  final RestaurantTable table;

  @override
  List<Object?> get props => [table];
}
