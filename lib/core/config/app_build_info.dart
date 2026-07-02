/// Visible build marker used to confirm which APK is installed on a device.
final class AppBuildInfo {
  const AppBuildInfo._();

  /// Application version from pubspec for the current release candidate.
  static const version = '0.1.6+11';

  /// Short marker shown on access/bootstrap screens during field testing.
  static const marker = 'PACKAGING-TO-GO-ONLY-20260701-01';

  /// User-facing build label.
  static const visibleLabel = 'APK v$version - $marker';
}
