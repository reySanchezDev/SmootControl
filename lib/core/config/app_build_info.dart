/// Visible build marker used to confirm which APK is installed on a device.
final class AppBuildInfo {
  const AppBuildInfo._();

  /// Application version from pubspec for the current release candidate.
  static const version = '0.1.82+87';

  /// Short marker shown on access/bootstrap screens during field testing.
  static const marker = 'TIME-CLOCK-PREMIUM-20260722-04';

  /// User-facing build label.
  static const visibleLabel = 'APK v$version - $marker';
}
