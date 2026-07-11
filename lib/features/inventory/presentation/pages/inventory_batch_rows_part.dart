part of 'inventory_page.dart';

class _BatchProductRow {
  _BatchProductRow(this.item)
    : quantityController = TextEditingController(),
      costController = TextEditingController(
        text: _formatMoney(item.costInCents),
      );

  final InventoryStockItem item;
  final TextEditingController quantityController;
  final TextEditingController costController;

  bool matches(String filter) {
    return _normalize(
      '${item.productName} ${item.categoryName ?? ''} '
      '${item.categoryPath ?? ''}',
    ).contains(filter);
  }

  void dispose() {
    quantityController.dispose();
    costController.dispose();
  }
}

class _BatchPackagingRow {
  _BatchPackagingRow(this.item)
    : quantityController = TextEditingController(),
      costController = TextEditingController(
        text: _formatMoney(item.costInCents),
      );

  final PackagingStockItem item;
  final TextEditingController quantityController;
  final TextEditingController costController;

  bool matches(String filter) {
    return _normalize(item.packagingName).contains(filter);
  }

  void dispose() {
    quantityController.dispose();
    costController.dispose();
  }
}

String _normalize(String value) {
  return value.trim().toLowerCase();
}

String _formatMoney(int cents) {
  final amount = cents / 100;
  return amount.toStringAsFixed(2);
}

int? _parseMoneyToCents(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final amount = num.tryParse(normalized);
  if (amount == null) return null;
  return (amount * 100).round();
}
