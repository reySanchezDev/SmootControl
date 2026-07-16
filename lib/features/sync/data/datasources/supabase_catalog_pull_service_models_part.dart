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

extension _CatalogPullModelHelpers on SupabaseCatalogPullService {
  List<Map<String, Object?>> _stockForProducts(
    List<Map<String, Object?>> rows,
    List<Map<String, Object?>> products,
  ) {
    final productIds = products
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toSet();
    return rows.where((row) {
      final productId = row['product_id']?.toString();
      return productId != null && productIds.contains(productId);
    }).toList();
  }
}
