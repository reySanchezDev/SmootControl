import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Builds a human-friendly name for the initialized POS device.
final class PosDeviceNameService {
  /// Creates the POS device name service.
  const PosDeviceNameService();

  /// Returns a readable device name when the platform exposes one.
  Future<String> resolveName() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        final info = await plugin.webBrowserInfo;
        return _clean('Web ${info.browserName.name}');
      }
      return switch (defaultTargetPlatform) {
        TargetPlatform.android => _androidName(await plugin.androidInfo),
        TargetPlatform.iOS => _iosName(await plugin.iosInfo),
        TargetPlatform.windows => _windowsName(await plugin.windowsInfo),
        TargetPlatform.macOS => _macName(await plugin.macOsInfo),
        TargetPlatform.linux => _linuxName(await plugin.linuxInfo),
        TargetPlatform.fuchsia => _fallbackName(),
      };
    } on Object {
      return _fallbackName();
    }
  }

  String _androidName(AndroidDeviceInfo info) {
    return _clean('${info.manufacturer} ${info.model}');
  }

  String _iosName(IosDeviceInfo info) {
    return _clean('${info.name} ${info.modelName}');
  }

  String _windowsName(WindowsDeviceInfo info) {
    return _clean(info.computerName);
  }

  String _macName(MacOsDeviceInfo info) {
    return _clean(info.computerName);
  }

  String _linuxName(LinuxDeviceInfo info) {
    return _clean(info.prettyName);
  }

  String _fallbackName() {
    return 'POS ${DateTime.now().toIso8601String()}';
  }

  String _clean(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return _fallbackName();
    return normalized.length > 80 ? normalized.substring(0, 80) : normalized;
  }
}
