/// Staff vacation request or backoffice vacation record.
final class VacationRequest {
  /// Creates a vacation request.
  const VacationRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.startDate,
    required this.endDate,
    required this.requestedDays,
    required this.requestType,
    required this.status,
    required this.source,
    required this.createdAt,
    this.note,
    this.deviceName,
    this.approvedAt,
  });

  /// Request identifier.
  final String id;

  /// Employee identifier.
  final String employeeId;

  /// Employee display name.
  final String employeeName;

  /// First vacation day.
  final DateTime startDate;

  /// Last vacation day.
  final DateTime endDate;

  /// Vacation days.
  final double requestedDays;

  /// planned or taken.
  final String requestType;

  /// pending, approved, rejected or cancelled.
  final String status;

  /// admin or time_clock.
  final String source;

  /// Optional note.
  final String? note;

  /// Device display name for marker-created requests.
  final String? deviceName;

  /// Approval timestamp.
  final DateTime? approvedAt;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Whether request is still waiting for backoffice approval.
  bool get isPending => status == 'pending';
}
