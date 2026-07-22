/// Runtime mode selected at build time.
abstract final class AppRunMode {
  /// Dart define used by the time-clock APK.
  static const value = String.fromEnvironment(
    'SMOO_APP_MODE',
    defaultValue: 'standard',
  );

  /// Whether this build should open the attendance marker directly.
  static bool get isTimeClock => value == 'time_clock';
}
