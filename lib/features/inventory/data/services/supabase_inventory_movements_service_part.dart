part of 'supabase_inventory_movements_service.dart';

InventoryMovementDocumentType _typeFromText(String value) => switch (value) {
  'purchase' => InventoryMovementDocumentType.purchase,
  'sale' => InventoryMovementDocumentType.sale,
  'sale_void' => InventoryMovementDocumentType.saleVoid,
  _ => InventoryMovementDocumentType.adjustment,
};

String _typeCode(InventoryMovementDocumentType type) => switch (type) {
  InventoryMovementDocumentType.purchase => 'purchase',
  InventoryMovementDocumentType.sale => 'sale',
  InventoryMovementDocumentType.saleVoid => 'sale_void',
  InventoryMovementDocumentType.adjustment => 'adjustment',
  InventoryMovementDocumentType.all => '',
};

String _genericTitle(
  InventoryMovementDocumentType type,
  List<Map<String, Object?>> rows,
  Map<String, String> products,
) {
  final firstProduct =
      products[rows.first['product_id']?.toString()] ?? 'Producto';
  return switch (type) {
    InventoryMovementDocumentType.purchase => 'Compra - $firstProduct',
    InventoryMovementDocumentType.sale => 'Venta',
    InventoryMovementDocumentType.saleVoid => 'Anulacion venta',
    InventoryMovementDocumentType.adjustment => 'Ajuste',
    InventoryMovementDocumentType.all => 'Movimiento',
  };
}

int _compareNewestFirst(
  InventoryMovementDocument a,
  InventoryMovementDocument b,
) {
  final byDate = b.createdAt.compareTo(a.createdAt);
  if (byDate != 0) return byDate;
  final byNumber = _titleNumber(b.title).compareTo(_titleNumber(a.title));
  if (byNumber != 0) return byNumber;
  return b.title.compareTo(a.title);
}

int _titleNumber(String title) {
  final match = RegExp(r'#(\d+)').firstMatch(title);
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}
