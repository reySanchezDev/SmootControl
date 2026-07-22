import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';
import 'package:smoo_control/features/staff/domain/entities/salary_advance.dart';

/// Local POS datasource for employees, business rules and salary advances.
final class LocalStaffDataSource {
  /// Creates the datasource.
  const LocalStaffDataSource(this._database);

  final AppDatabase _database;

  /// Active employees available in POS.
  Future<List<Employee>> getActiveEmployees() async {
    final rows =
        await (_database.select(_database.localEmployees)
              ..where((employee) => employee.isActive.equals(true))
              ..orderBy([(employee) => OrderingTerm.asc(employee.fullName)]))
            .get();
    return rows.map(_employeeFromRow).toList();
  }

  /// Returns a boolean rule, falling back to the given default.
  Future<bool> getBoolRule(String key, {required bool defaultValue}) async {
    final row = await (_database.select(
      _database.localBusinessRules,
    )..where((rule) => rule.key.equals(key))).getSingleOrNull();
    return row?.boolValue ?? defaultValue;
  }

  /// Saves a local POS salary advance.
  Future<SalaryAdvance> saveSalaryAdvance(SalaryAdvance advance) async {
    final now = DateTime.now();
    await _database
        .into(_database.localSalaryAdvances)
        .insertOnConflictUpdate(
          LocalSalaryAdvancesCompanion(
            id: Value(advance.id),
            employeeId: Value(advance.employeeId),
            cashRegisterSessionId: Value(advance.cashRegisterSessionId),
            amountInCents: Value(advance.amountInCents),
            affectsCash: Value(advance.affectsCash),
            note: Value(advance.note),
            createdBy: Value(advance.createdBy),
            deliveredAt: Value(advance.deliveredAt),
            status: Value(advance.status),
            createdAt: Value(advance.createdAt),
            updatedAt: Value(now),
          ),
        );
    return advance;
  }

  Employee _employeeFromRow(LocalEmployee row) {
    return Employee(
      id: row.id,
      code: row.code,
      fullName: row.fullName,
      positionName: row.positionName,
      baseSalaryInCents: row.baseSalaryInCents,
      isActive: row.isActive,
      photoUrl: row.photoUrl,
      showInTimeClock: row.showInTimeClock,
    );
  }
}
