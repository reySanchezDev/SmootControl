part of 'pos_bloc.dart';

List<SaleItem> _buildSplitItems({
  required AccountSplitDraft account,
  required PosReady current,
  required String saleId,
  required DateTime createdAt,
}) {
  final productById = {
    for (final product in current.products) product.id: product,
  };
  final sourceLines =
      current.splitSourceLinesByTable[account.tableId] ?? current.cartLines;
  final draftById = {
    for (final item in _splitDraftItemsFromLines(sourceLines)) item.id: item,
  };

  return _consolidateSaleItems([
    for (final itemId in account.itemIds)
      SaleItem(
        id: const Uuid().v4(),
        saleId: saleId,
        tableId: current.selectedTableId,
        tableAccountId: account.id,
        productId: draftById[itemId]!.productId,
        productName: draftById[itemId]!.productName,
        selectedOptionsLabel: draftById[itemId]!.selectedOptionsLabel,
        categoryName: _categoryName(
          categories: current.categories,
          categoryId: productById[draftById[itemId]!.productId]!.categoryId,
        ),
        quantity: 1,
        unitPriceInCents: draftById[itemId]!.unitPriceInCents,
        unitCostInCents: productById[draftById[itemId]!.productId]!.costInCents,
        createdAt: createdAt,
      ),
  ]);
}

List<SaleItem> _buildConsolidatedSaleItems({
  required List<PosCartLine> lines,
  required PosReady current,
  required String saleId,
  required DateTime createdAt,
}) {
  return _consolidateSaleItems([
    for (final line in lines)
      SaleItem(
        id: const Uuid().v4(),
        saleId: saleId,
        tableId: current.selectedTableId,
        productId: line.product.id,
        productName: line.product.name,
        categoryName: _categoryName(
          categories: current.categories,
          categoryId: line.product.categoryId,
        ),
        selectedOptionsLabel: line.selectedOptionsLabel.isEmpty
            ? null
            : line.selectedOptionsLabel,
        quantity: line.quantity,
        unitPriceInCents: line.product.priceInCents,
        unitCostInCents: line.product.costInCents,
        createdAt: createdAt,
      ),
  ]);
}

List<SaleItem> _consolidateSaleItems(List<SaleItem> items) {
  final itemsByKey = <String, SaleItem>{};
  for (final item in items) {
    final key = [
      item.tableId ?? '',
      item.tableAccountId ?? '',
      item.productId,
      item.productName,
      item.categoryName,
      item.selectedOptionsLabel ?? '',
      item.unitPriceInCents,
      item.unitCostInCents,
    ].join('|');
    final existing = itemsByKey[key];
    if (existing == null) {
      itemsByKey[key] = item;
      continue;
    }
    itemsByKey[key] = SaleItem(
      id: existing.id,
      saleId: existing.saleId,
      tableId: existing.tableId,
      tableAccountId: existing.tableAccountId,
      productId: existing.productId,
      productName: existing.productName,
      selectedOptionsLabel: existing.selectedOptionsLabel,
      categoryName: existing.categoryName,
      quantity: existing.quantity + item.quantity,
      unitPriceInCents: existing.unitPriceInCents,
      unitCostInCents: existing.unitCostInCents,
      createdAt: existing.createdAt,
    );
  }
  return itemsByKey.values.toList();
}

List<SaleItemDraft> _splitDraftItemsFromLines(List<PosCartLine> lines) {
  final items = <SaleItemDraft>[];
  for (final line in lines) {
    for (var index = 0; index < line.quantity; index += 1) {
      final itemId = '${line.lineKey}-$index';
      items.add(
        SaleItemDraft(
          id: itemId,
          productId: line.product.id,
          productName: line.product.name,
          selectedOptionsLabel: line.selectedOptionsLabel.isEmpty
              ? null
              : line.selectedOptionsLabel,
          quantity: 1,
          unitPriceInCents: line.product.priceInCents,
        ),
      );
    }
  }
  return items;
}

List<PosCartLine> _cartLinesForSplitAccount(
  AccountSplitDraft account,
  List<PosCartLine> sourceLines,
) {
  final selectedIds = account.itemIds.toSet();
  final linesByKey = <String, PosCartLine>{};
  for (final line in sourceLines) {
    var quantity = 0;
    for (var index = 0; index < line.quantity; index += 1) {
      final itemId = '${line.lineKey}-$index';
      if (selectedIds.contains(itemId)) quantity += 1;
    }
    if (quantity > 0) {
      linesByKey[line.lineKey] = PosCartLine(
        product: line.product,
        quantity: quantity,
        isServed: line.isServed,
        ticketLineId: line.lineKey,
        selectedOptions: line.selectedOptions,
      );
    }
  }
  return linesByKey.values.toList();
}
