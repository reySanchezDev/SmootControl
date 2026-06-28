import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';

/// Calculated cash register totals for a daily session.
final class CashRegisterSummary extends Equatable {
  /// Creates a calculated cash register summary.
  const CashRegisterSummary({
    required this.session,
    required this.cashSalesInCents,
    required this.expensesInCents,
  });

  /// Cash register session being summarized.
  final CashRegisterSession session;

  /// Completed sales paid with methods that affect cash.
  final int cashSalesInCents;

  /// Operational expenses paid from this cash register.
  final int expensesInCents;

  /// Expected physical cash at closing.
  int get expectedClosingCashInCents {
    return session.openingCashInCents + cashSalesInCents - expensesInCents;
  }

  /// Difference between physical count and expected cash.
  int? get differenceInCents {
    final physical = session.physicalClosingCashInCents;
    if (physical == null) return null;

    return physical - expectedClosingCashInCents;
  }

  @override
  List<Object?> get props => [
    session,
    cashSalesInCents,
    expensesInCents,
    expectedClosingCashInCents,
    differenceInCents,
  ];
}
