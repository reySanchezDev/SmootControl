part of 'inventory_page.dart';

class _BatchPackagingPurchaseDialog extends StatefulWidget {
  const _BatchPackagingPurchaseDialog({
    required this.items,
    required this.writeService,
  });

  final List<PackagingStockItem> items;
  final SupabaseInventoryAdminWriteService writeService;

  @override
  State<_BatchPackagingPurchaseDialog> createState() =>
      _BatchPackagingPurchaseDialogState();
}

class _BatchPackagingPurchaseDialogState
    extends State<_BatchPackagingPurchaseDialog> {
  final _filterController = TextEditingController();
  late final List<_BatchPackagingRow> _rows;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rows = [
      for (final item in widget.items) _BatchPackagingRow(item),
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
    final mediaSize = MediaQuery.sizeOf(context);
    final isCompact = mediaSize.width < 560;
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
      title: const AppText(
        'Registrar compra de empaques por lote',
        variant: AppTextVariant.titleMedium,
        maxLines: 2,
      ),
      content: SizedBox(
        width: isCompact ? double.maxFinite : 720,
        height: _batchDialogHeight(mediaSize, isCompact),
        child: Column(
          children: [
            AppInput(
              label: 'Filtrar empaque',
              controller: _filterController,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (!isCompact) ...[
              const _BatchPurchaseHeader(productLabel: 'EMPAQUE'),
              const Divider(height: 1),
            ],
            Expanded(
              child: visibleRows.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.search_off,
                      title: 'Sin resultados',
                      message: 'Ajusta el filtro para ver empaques.',
                    )
                  : ListView.separated(
                      itemCount: visibleRows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) =>
                          _PackagingBatchPurchaseTile(
                            row: visibleRows[index],
                            compact: isCompact,
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
      actionsOverflowButtonSpacing: 8,
      actions: [
        AppButton(
          label: 'Cancelar',
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          primary: false,
        ),
        AppButton(
          label: _saving ? 'Guardando...' : 'Guardar lote',
          icon: Icons.save_outlined,
          onPressed: _saving ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final purchaseItems = <AdminPackagingPurchaseItem>[];
    for (final row in _rows) {
      final quantity = int.tryParse(row.quantityController.text.trim()) ?? 0;
      if (quantity <= 0) continue;
      final cost = _parseMoneyToCents(row.costController.text);
      if (cost == null || cost < 0) {
        setState(() {
          _error = 'Revisa el costo de ${row.item.packagingName}.';
        });
        return;
      }
      purchaseItems.add(
        AdminPackagingPurchaseItem(
          packagingItemId: row.item.packagingItemId,
          quantity: quantity,
          unitCostInCents: cost,
        ),
      );
    }

    if (purchaseItems.isEmpty) {
      setState(() => _error = 'Agrega cantidad al menos a un empaque.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.writeService.registerPackagingPurchaseBatch(
      purchaseItems,
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
