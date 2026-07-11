part of 'supabase_sync_remote_sender.dart';

final class _DeviceSyncCredentials {
  const _DeviceSyncCredentials({
    required this.deviceId,
    required this.deviceSecret,
  });

  final String deviceId;
  final String deviceSecret;
}
