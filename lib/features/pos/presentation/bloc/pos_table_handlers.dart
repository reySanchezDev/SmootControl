part of 'pos_bloc.dart';

Future<void> _handleTableDisplayNameChanged(
  PosBloc bloc,
  PosTableDisplayNameChanged event,
  Emitter<PosState> emit,
) async {
  final current = bloc.state;
  if (current is! PosReady) return;

  final table = _findTable(current.tables, event.tableId);
  if (table == null) return;

  final displayName = _normalizedDisplayName(
    internalName: table.name,
    value: event.displayName,
  );
  final updated = _copyRestaurantTable(table, displayName: displayName);
  final saved = await _saveTable(bloc, updated, emit);
  if (saved == null) {
    emit(current);
    return;
  }

  emit(
    current.copyWith(
      tables: _replaceTable(current.tables, saved),
      clearLastCompletedSale: true,
    ),
  );
}

Future<List<RestaurantTable>?> _resetSelectedTableDisplayNameIfNeeded(
  PosBloc bloc,
  PosReady current,
  Emitter<PosState> emit,
) async {
  final tableId = current.selectedTableId;
  if (tableId == null) return current.tables;

  final table = _findTable(current.tables, tableId);
  if (table == null || table.displayName == null) return current.tables;

  final saved = await _saveTable(
    bloc,
    _copyRestaurantTable(table),
    emit,
  );
  if (saved == null) return null;

  return _replaceTable(current.tables, saved);
}

Future<RestaurantTable?> _saveTable(
  PosBloc bloc,
  RestaurantTable table,
  Emitter<PosState> emit,
) async {
  final result = await bloc._tablesRepository.saveTable(table);
  switch (result) {
    case AppSuccess(:final value):
      return value;
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      return null;
  }
}

RestaurantTable? _findTable(List<RestaurantTable> tables, String tableId) {
  for (final table in tables) {
    if (table.id == tableId) return table;
  }
  return null;
}

String? _normalizedDisplayName({
  required String internalName,
  required String value,
}) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized == internalName) return null;
  return normalized;
}

RestaurantTable _copyRestaurantTable(
  RestaurantTable table, {
  String? displayName,
}) {
  return RestaurantTable(
    id: table.id,
    name: table.name,
    status: table.status,
    isActive: table.isActive,
    displayName: displayName,
  );
}

List<RestaurantTable> _replaceTable(
  List<RestaurantTable> tables,
  RestaurantTable updated,
) {
  return [
    for (final table in tables)
      if (table.id == updated.id) updated else table,
  ];
}
