import 'package:equatable/equatable.dart';

/// Operational rule controlled by the administrative module.
final class BusinessRule extends Equatable {
  /// Creates a business rule.
  const BusinessRule({
    required this.key,
    this.boolValue,
    this.textValue,
  });

  /// Salary advance POS cash rule.
  static const salaryAdvancePosAffectsCash = 'salary_advance_pos_affects_cash';

  /// Stable rule key.
  final String key;

  /// Boolean rule value.
  final bool? boolValue;

  /// Text rule value reserved for future use.
  final String? textValue;

  @override
  List<Object?> get props => [key, boolValue, textValue];
}
