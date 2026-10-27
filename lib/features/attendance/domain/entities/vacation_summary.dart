/// Consolidated vacation balance for one employee.
final class VacationSummary {
  /// Creates a vacation balance row.
  const VacationSummary({
    required this.employeeId,
    required this.employeeName,
    required this.startDate,
    required this.accumulatedDays,
    required this.takenDays,
    required this.scheduledDays,
    required this.currentBalance,
    required this.projectedBalance,
    this.scheduledFrom,
    this.scheduledTo,
  });

  /// Employee identifier.
  final String employeeId;

  /// Employee name.
  final String employeeName;

  /// Accrual start date.
  final DateTime startDate;

  /// Days accumulated up to report date.
  final double accumulatedDays;

  /// Approved days already taken.
  final double takenDays;

  /// Approved future days.
  final double scheduledDays;

  /// First scheduled date, if any.
  final DateTime? scheduledFrom;

  /// Last scheduled date, if any.
  final DateTime? scheduledTo;

  /// Balance without future schedule.
  final double currentBalance;

  /// Balance after future schedule.
  final double projectedBalance;
}
