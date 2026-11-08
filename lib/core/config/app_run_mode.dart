/// Runtime mode selected at build time.
abstract final class AppRunMode {
  /// Dart define used by the time-clock APK.
  static const value = String.fromEnvironment(
    'SMOO_APP_MODE',
    defaultValue: 'standard',
  );

  /// Direct remote-admin Backoffice: no POS device provisioning.
  static bool get isBackoffice => value == 'backoffice';

  /// Whether this build should open the attendance marker directly.
  static bool get isTimeClock => value == 'time_clock';
}
