import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/utils/business_date_formatter.dart';
import 'package:smoo_control/features/cash_register/data/models/cash_register_session_model.dart';
import 'package:smoo_control/features/cash_register/data/models/cash_register_summary_model.dart';

/// Local datasource for daily cash register sessions.
final class LocalCashRegisterDataSource {
  /// Creates a local cash register datasource.
  const LocalCashRegisterDataSource(this._database);

  final AppDatabase _database;

  /// Opens a local cash register session.
  Future<CashRegisterSessionModel> openSession(
    CashRegisterSessionModel session,
  ) async {
    final now = DateTime.now();

    await _database
        .into(_database.localCashRegisterSessions)
        .insertOnConflictUpdate(
          LocalCashRegisterSessionsCompanion(
            id: Value(session.id),
            cashierId: Value(session.cashierId),
            businessDate: Value(session.businessDateValue),
            openingCashInCents: Value(session.openingCashInCents),
            physicalClosingCashInCents: Value(
              session.physicalClosingCashInCents,
            ),
            status: Value(session.statusValue),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return session;
  }

  /// Returns the open cash register session for a business date, if any.
  Future<CashRegisterSessionModel?> getOpenSession(
    DateTime businessDate,
  ) async {
    final businessDateValue = BusinessDateFormatter.format(businessDate);
    final query = _database.select(_database.localCashRegisterSessions)
      ..where((session) {
        return session.businessDate.equals(businessDateValue) &
            session.status.equals('open');
      })
      ..orderBy([(session) => OrderingTerm.desc(session.createdAt)])
      ..limit(1);
    final row = await query.getSingleOrNull();

    return row == null ? null : CashRegisterSessionModel.fromLocal(row);
  }

  /// Returns the open cash register session for one cashier, if any.
  Future<CashRegisterSessionModel?> getOpenSessionForCashier({
    required DateTime businessDate,
    required String cashierId,
  }) async {
    final businessDateValue = BusinessDateFormatter.format(businessDate);
    final query = _database.select(_database.localCashRegisterSessions)
      ..where((session) {
        return session.businessDate.equals(businessDateValue) &
            session.cashierId.equals(cashierId) &
            session.status.equals('open');
      })
      ..orderBy([(session) => OrderingTerm.desc(session.createdAt)])
      ..limit(1);
    final row = await query.getSingleOrNull();

    return row == null ? null : CashRegisterSessionModel.fromLocal(row);
  }

  /// Returns any open cash register session for one cashier, if any.
  Future<CashRegisterSessionModel?> getAnyOpenSessionForCashier(
    String cashierId,
  ) async {
    final query = _database.select(_database.localCashRegisterSessions)
      ..where((session) {
        return session.cashierId.equals(cashierId) &
            session.status.equals('open');
      })
      ..orderBy([(session) => OrderingTerm.asc(session.businessDate)])
      ..limit(1);
    final row = await query.getSingleOrNull();

    return row == null ? null : CashRegisterSessionModel.fromLocal(row);
  }

  /// Returns cash register sessions inside a business date range.
  Future<List<CashRegisterSessionModel>> getSessions({
    required DateTime from,
    required DateTime to,
  }) async {
    final fromValue = BusinessDateFormatter.format(from);
    final toValue = BusinessDateFormatter.format(to);
    final query = _database.select(_database.localCashRegisterSessions)
      ..where((session) {
        return session.businessDate.isBiggerOrEqualValue(fromValue) &
            session.businessDate.isSmallerThanValue(toValue);
      })
      ..orderBy([(session) => OrderingTerm.asc(session.businessDate)]);
    final rows = await query.get();

    return rows.map(CashRegisterSessionModel.fromLocal).toList();
  }

  /// Returns calculated totals for a cash register session.
  Future<CashRegisterSummaryModel> getSummary(
    CashRegisterSessionModel session,
  ) async {
    final cashPaymentMethods = await (_database.select(
      _database.localPaymentMethods,
    )..where((method) => method.affectsCashRegister.equals(true))).get();
    final cashMethodIds = cashPaymentMethods.map((method) => method.id).toSet();

    final sales =
        await (_database.select(_database.localSales)..where((sale) {
              return sale.cashRegisterSessionId.equals(session.id) &
                  sale.status.equals('completed');
            }))
            .get();
    final cashSalesInCents = sales
        .where((sale) => cashMethodIds.contains(sale.paymentMethodId))
        .fold(0, (sum, sale) => sum + sale.totalInCents);

    final expenses =
        await (_database.select(
              _database.localOperatingExpenses,
            )..where((expense) {
              return expense.cashRegisterSessionId.equals(session.id);
            }))
            .get();
    final expensesInCents = expenses.fold(
      0,
      (sum, expense) => sum + expense.amountInCents,
    );

    return CashRegisterSummaryModel(
      session: session,
      cashSalesInCents: cashSalesInCents,
      expensesInCents: expensesInCents,
    );
  }

  /// Closes a local cash register session.
  Future<CashRegisterSessionModel> closeSession({
    required String sessionId,
    required int physicalClosingCashInCents,
  }) async {
    final now = DateTime.now();
    await (_database.update(
      _database.localCashRegisterSessions,
    )..where((session) => session.id.equals(sessionId))).write(
      LocalCashRegisterSessionsCompanion(
        physicalClosingCashInCents: Value(physicalClosingCashInCents),
        status: const Value('closed'),
        updatedAt: Value(now),
      ),
    );

    final row = await (_database.select(
      _database.localCashRegisterSessions,
    )..where((session) => session.id.equals(sessionId))).getSingle();

    return CashRegisterSessionModel.fromLocal(row);
  }
}
