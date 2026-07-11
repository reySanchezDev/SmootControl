part of 'supabase_catalog_pull_service.dart';

final class _ProductModifierLink {
  const _ProductModifierLink(this.groupId, this.order);

  final String groupId;
  final int order;
}

final class _DeviceCatalogCredentials {
  const _DeviceCatalogCredentials({
    required this.deviceId,
    required this.deviceSecret,
  });

  final String deviceId;
  final String deviceSecret;
}
