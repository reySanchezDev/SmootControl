import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/cash_register/data/models/cash_register_session_model.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_summary.dart';

/// Data model for calculated cash register totals.
final class CashRegisterSummaryModel extends Equatable {
  /// Creates a cash register summary model.
  const CashRegisterSummaryModel({
    required this.session,
    required this.cashSalesInCents,
    required this.expensesInCents,
  });

  /// Session being summarized.
  final CashRegisterSessionModel session;

  /// Completed sales paid with methods that affect cash.
  final int cashSalesInCents;

  /// Operational expenses paid from this cash register.
  final int expensesInCents;

  /// Converts this model to a domain entity.
  CashRegisterSummary toEntity() {
    return CashRegisterSummary(
      session: session.toEntity(),
      cashSalesInCents: cashSalesInCents,
      expensesInCents: expensesInCents,
    );
  }

  @override
  List<Object?> get props => [session, cashSalesInCents, expensesInCents];
}
