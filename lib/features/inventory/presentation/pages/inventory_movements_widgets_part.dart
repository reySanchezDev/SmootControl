part of 'inventory_movements_page.dart';

class _MovementFilters extends StatelessWidget {
  const _MovementFilters({
    required this.from,
    required this.onChanged,
    required this.onReload,
    required this.to,
    required this.type,
  });

  final DateTime from;
  final void Function(InventoryMovementDocumentType, DateTime, DateTime)
  onChanged;
  final VoidCallback onReload;
  final DateTime to;
  final InventoryMovementDocumentType type;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          DropdownButtonFormField<InventoryMovementDocumentType>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Tipo de movimiento',
            ),
            initialValue: type,
            items: [
              for (final item in InventoryMovementDocumentType.values)
                DropdownMenuItem(value: item, child: AppText(_typeLabel(item))),
            ],
            onChanged: (value) => onChanged(value ?? type, from, to),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  icon: Icons.date_range,
                  label: 'Desde ${_dateText(from)}',
                  onPressed: () => unawaited(_pick(context, from, true)),
                  primary: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  icon: Icons.event,
                  label: 'Hasta ${_dateText(to)}',
                  onPressed: () => unawaited(_pick(context, to, false)),
                  primary: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppButton(
            icon: Icons.refresh,
            label: 'Recargar',
            onPressed: onReload,
          ),
        ],
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    DateTime initialDate,
    bool isFrom,
  ) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      initialDate: initialDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    onChanged(type, isFrom ? selected : from, isFrom ? to : selected);
  }
}

class _MovementHeaderTile extends StatelessWidget {
  const _MovementHeaderTile({required this.document, required this.onTap});

  final InventoryMovementDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final delta = document.quantityDelta;
    return ListTile(
      leading: Icon(_typeIcon(document.type)),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      subtitle: AppText(
        '${_dateTimeText(document.createdAt)} - '
        '${document.lineCount} lineas - Neto: ${delta > 0 ? '+' : ''}$delta',
        variant: AppTextVariant.label,
      ),
      title: AppText(
        document.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _MovementDetailSheet extends StatelessWidget {
  const _MovementDetailSheet({required this.document});

  final InventoryMovementDocument document;

  SupabaseInventoryMovementsService get _service =>
      serviceLocator<SupabaseInventoryMovementsService>();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FutureBuilder<AppResult<List<InventoryMovementDocumentLine>>>(
          future: _service.loadLines(document),
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null) return const AppLoadingPage();
            return data.when(
              success: (lines) =>
                  _MovementLines(document: document, lines: lines),
              failure: (error) => AppEmptyState(
                icon: Icons.error_outline,
                message: error.message,
                title: 'No se pudo cargar',
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MovementLines extends StatelessWidget {
  const _MovementLines({required this.document, required this.lines});

  final InventoryMovementDocument document;
  final List<InventoryMovementDocumentLine> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(document.title, variant: AppTextVariant.titleMedium),
        const SizedBox(height: 4),
        AppText(
          '${_typeLabel(document.type)} - ${_dateTimeText(document.createdAt)}',
          variant: AppTextVariant.label,
        ),
        const Divider(height: 24),
        Expanded(
          child: ListView.separated(
            itemBuilder: (context, index) =>
                _MovementLineTile(line: lines[index]),
            itemCount: lines.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
          ),
        ),
      ],
    );
  }
}

class _MovementLineTile extends StatelessWidget {
  const _MovementLineTile({required this.line});

  final InventoryMovementDocumentLine line;

  @override
  Widget build(BuildContext context) {
    final cost = line.unitCostInCents;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: AppText(
        line.productName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: AppText(
        [
          if (line.stockBefore != null) 'Sistema: ${line.stockBefore}',
          if (line.countedQuantity != null) 'Conteo: ${line.countedQuantity}',
          if (cost != null) 'Costo: ${MoneyFormatter.format(cost)}',
        ].join(' - '),
        variant: AppTextVariant.label,
      ),
      trailing: AppText(
        '${line.quantityDelta > 0 ? '+' : ''}${line.quantityDelta}',
        variant: AppTextVariant.titleMedium,
      ),
    );
  }
}

String _dateText(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _dateTimeText(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${_dateText(date)} $hour:$minute';
}

IconData _typeIcon(InventoryMovementDocumentType type) => switch (type) {
  InventoryMovementDocumentType.purchase => Icons.add_shopping_cart_outlined,
  InventoryMovementDocumentType.adjustment => Icons.fact_check_outlined,
  InventoryMovementDocumentType.sale => Icons.point_of_sale_outlined,
  InventoryMovementDocumentType.saleVoid => Icons.undo_outlined,
  InventoryMovementDocumentType.all => Icons.inventory_2_outlined,
};

String _typeLabel(InventoryMovementDocumentType type) => switch (type) {
  InventoryMovementDocumentType.all => 'Todos',
  InventoryMovementDocumentType.purchase => 'Compras',
  InventoryMovementDocumentType.adjustment => 'Ajustes',
  InventoryMovementDocumentType.sale => 'Ventas',
  InventoryMovementDocumentType.saleVoid => 'Anulaciones',
};
