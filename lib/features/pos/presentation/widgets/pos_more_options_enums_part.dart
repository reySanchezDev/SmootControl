part of 'pos_more_options_panel.dart';

enum _MoreOptionAction {
  clearCart,
  closeCashRegister,
  exit,
  modifierAvailability,
  registerExpense,
  salaryAdvance,
  splitAccounts,
  staffConsumption,
  syncData,
  viewTransactions,
}

enum _MoreOptionButtonTone { danger, neutral }

String _shortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
