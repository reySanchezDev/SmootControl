part of 'packaging_page.dart';

class _PackagingSnapshot {
  const _PackagingSnapshot({
    required this.packagingItems,
    required this.products,
    required this.rules,
    required this.salesTypes,
  });

  final List<PackagingItem> packagingItems;
  final List<Product> products;
  final List<ProductPackagingRule> rules;
  final List<SalesType> salesTypes;
}
