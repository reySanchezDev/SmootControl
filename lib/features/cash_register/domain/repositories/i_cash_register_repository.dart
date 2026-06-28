import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_summary.dart';

/// Contract for daily cash register operations.
abstract interface class ICashRegisterRepository {
  /// Opens a daily cash register session.
  Future<AppResult<CashRegisterSession>> openSession(
    CashRegisterSession session,
  );

  /// Returns the open cash register session for a business date, if any.
  Future<AppResult<CashRegisterSession?>> getOpenSession(DateTime businessDate);

  /// Returns the open cash register session for one cashier and business date.
  Future<AppResult<CashRegisterSession?>> getOpenSessionForCashier({
    required DateTime businessDate,
    required String cashierId,
  });

  /// Returns any open cash register session for one cashier.
  Future<AppResult<CashRegisterSession?>> getAnyOpenSessionForCashier(
    String cashierId,
  );

  /// Returns cash register sessions whose business date is inside the range.
  Future<AppResult<List<CashRegisterSession>>> getSessions({
    required DateTime from,
    required DateTime to,
  });

  /// Returns calculated totals for a cash register session.
  Future<AppResult<CashRegisterSummary>> getSummary(
    CashRegisterSession session,
  );

  /// Closes a daily cash register session.
  Future<AppResult<CashRegisterSession>> closeSession({
    required String sessionId,
    required int physicalClosingCashInCents,
  });
}
