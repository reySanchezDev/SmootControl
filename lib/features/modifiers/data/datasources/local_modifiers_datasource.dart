import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/modifiers/data/models/modifier_group_model.dart';
import 'package:smoo_control/features/modifiers/data/models/modifier_option_model.dart';

/// Local datasource for reusable POS modifiers.
final class LocalModifiersDataSource {
  /// Creates a datasource.
  const LocalModifiersDataSource(this._database);

  final AppDatabase _database;

  /// Returns all modifier groups.
  Future<List<ModifierGroupModel>> getGroups() async {
    final query = _database.select(_database.localModifierGroups)
      ..orderBy([
        (group) => OrderingTerm.asc(group.displayOrder),
        (group) => OrderingTerm.asc(group.name),
      ]);
    final rows = await query.get();
    return rows.map(ModifierGroupModel.fromLocal).toList();
  }

  /// Returns all modifier options.
  Future<List<ModifierOptionModel>> getOptions() async {
    final query = _database.select(_database.localModifierOptions)
      ..orderBy([
        (option) => OrderingTerm.asc(option.groupId),
        (option) => OrderingTerm.asc(option.displayOrder),
        (option) => OrderingTerm.asc(option.name),
      ]);
    final rows = await query.get();
    return rows.map(ModifierOptionModel.fromLocal).toList();
  }

  /// Inserts or updates a modifier group.
  Future<ModifierGroupModel> saveGroup(ModifierGroupModel group) async {
    final now = DateTime.now();
    await _database
        .into(_database.localModifierGroups)
        .insertOnConflictUpdate(
          LocalModifierGroupsCompanion(
            id: Value(group.id),
            name: Value(group.name),
            isRequired: Value(group.isRequired),
            displayOrder: Value(group.displayOrder),
            isActive: Value(group.isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return group;
  }

  /// Inserts or updates a modifier option.
  Future<ModifierOptionModel> saveOption(ModifierOptionModel option) async {
    final now = DateTime.now();
    await _database
        .into(_database.localModifierOptions)
        .insertOnConflictUpdate(
          LocalModifierOptionsCompanion(
            id: Value(option.id),
            groupId: Value(option.groupId),
            name: Value(option.name),
            priceDeltaInCents: Value(option.priceDeltaInCents),
            displayOrder: Value(option.displayOrder),
            isActive: Value(option.isActive),
            isAvailableInPos: Value(option.isAvailableInPos),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return option;
  }
}
