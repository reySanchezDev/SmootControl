import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';

/// Base event for cash register state management.
sealed class CashRegisterEvent extends Equatable {
  /// Creates a cash register event.
  const CashRegisterEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the current daily cash register session, if any.
final class CashRegisterStarted extends CashRegisterEvent {
  /// Creates the started event.
  const CashRegisterStarted();
}

/// Opens a daily cash register session.
final class CashRegisterOpened extends CashRegisterEvent {
  /// Creates an open event.
  const CashRegisterOpened(this.session);

  /// Session to open.
  final CashRegisterSession session;

  @override
  List<Object?> get props => [session];
}

/// Closes a daily cash register session.
final class CashRegisterClosed extends CashRegisterEvent {
  /// Creates a close event.
  const CashRegisterClosed({
    required this.sessionId,
    required this.physicalClosingCashInCents,
  });

  /// Session identifier.
  final String sessionId;

  /// Physical cash counted at close.
  final int physicalClosingCashInCents;

  @override
  List<Object?> get props => [sessionId, physicalClosingCashInCents];
}
