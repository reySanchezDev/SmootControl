part of 'inventory_page.dart';

class _InventoryAdjustmentDialog extends StatefulWidget {
  const _InventoryAdjustmentDialog({
    required this.items,
    required this.writeService,
  });

  final List<InventoryStockItem> items;
  final SupabaseInventoryAdminWriteService writeService;

  @override
  State<_InventoryAdjustmentDialog> createState() =>
      _InventoryAdjustmentDialogState();
}

class _InventoryAdjustmentDialogState
    extends State<_InventoryAdjustmentDialog> {
  final _filterController = TextEditingController();
  late final List<_InventoryAdjustmentRow> _rows;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rows = [
      for (final item in widget.items) _InventoryAdjustmentRow(item),
    ];
  }

  @override
  void dispose() {
    _filterController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mediaSize = MediaQuery.sizeOf(context);
    final isCompact = mediaSize.width < 620;
    final filter = _normalize(_filterController.text);
    final visibleRows = [
      for (final row in _rows)
        if (filter.isEmpty || row.matches(filter)) row,
    ];
    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 40,
        vertical: isCompact ? 16 : 24,
      ),
      title: AppText(
        l10n.inventoryAdjustmentTitle,
        variant: AppTextVariant.titleMedium,
        maxLines: 2,
      ),
      content: SizedBox(
        width: isCompact ? double.maxFinite : 760,
        height: _batchDialogHeight(mediaSize, isCompact),
        child: Column(
          children: [
            AppInput(
              label: l10n.inventoryAdjustmentFilter,
              controller: _filterController,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _InventoryAdjustmentSummary(rows: _rows),
            const SizedBox(height: 12),
            Expanded(
              child: visibleRows.isEmpty
                  ? AppEmptyState(
                      icon: Icons.search_off,
                      title: l10n.inventoryAdjustmentEmptyTitle,
                      message: l10n.inventoryAdjustmentEmptyMessage,
                    )
                  : ListView.separated(
                      itemCount: visibleRows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _InventoryAdjustmentTile(
                        row: visibleRows[index],
                        onChanged: () => setState(() {}),
                      ),
                    ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AppText(_error!, maxLines: 3),
            ],
          ],
        ),
      ),
      actionsPadding: EdgeInsets.fromLTRB(16, 0, 16, isCompact ? 16 : 20),
      actions: [
        AppButton(
          label: l10n.cancelAction,
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          primary: false,
        ),
        AppButton(
          label: _saving ? l10n.savingAction : l10n.inventoryAdjustmentSave,
          icon: Icons.save_outlined,
          onPressed: _saving ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final adjustmentItems = <AdminInventoryAdjustmentItem>[];
    for (final row in _rows) {
      if (row.countController.text.trim().isEmpty) continue;
      final counted = row.countedQuantity;
      if (counted == null || counted < 0) {
        setState(() => _error = l10n.inventoryAdjustmentInvalidCount);
        return;
      }
      if (counted == row.item.quantityOnHand) continue;
      adjustmentItems.add(
        AdminInventoryAdjustmentItem(
          productId: row.item.productId,
          expectedQuantity: row.item.quantityOnHand,
          countedQuantity: counted,
        ),
      );
    }

    if (adjustmentItems.isEmpty) {
      setState(() => _error = l10n.inventoryAdjustmentNoChanges);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.writeService.registerInventoryAdjustmentBatch(
      adjustmentItems,
    );
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        Navigator.of(context).pop(true);
      case AppFailureResult(:final error):
        setState(() {
          _saving = false;
          _error = error.message;
        });
    }
  }
}

class _InventoryAdjustmentRow {
  _InventoryAdjustmentRow(this.item)
    : countController = TextEditingController();

  final InventoryStockItem item;
  final TextEditingController countController;

  int? get countedQuantity {
    final text = countController.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  int? get delta {
    final counted = countedQuantity;
    if (counted == null) return null;
    return counted - item.quantityOnHand;
  }

  bool matches(String filter) {
    return _normalize(
      '${item.productName} ${item.categoryName ?? ''} '
      '${item.categoryPath ?? ''}',
    ).contains(filter);
  }

  void dispose() {
    countController.dispose();
  }
}
