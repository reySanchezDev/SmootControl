part of 'staff_admin_pages.dart';

/// Admin page for staff consumption receipts.
class StaffConsumptionsPage extends StatefulWidget {
  /// Creates the page.
  const StaffConsumptionsPage({super.key});

  @override
  State<StaffConsumptionsPage> createState() => _StaffConsumptionsPageState();
}

class _StaffConsumptionsPageState extends State<StaffConsumptionsPage> {
  late Future<AppResult<List<StaffConsumption>>> _future;

  SupabaseStaffAdminRepository get _repository =>
      serviceLocator<SupabaseStaffAdminRepository>();

  @override
  void initState() {
    super.initState();
    _future = _repository.getStaffConsumptions();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Consumos de personal',
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<AppResult<List<StaffConsumption>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const AppLoadingPage();
                return switch (snapshot.requireData) {
                  AppSuccess(:final value) => _StaffConsumptionList(
                    consumptions: value,
                    hasFilter: false,
                    onDelete: _deleteConsumption,
                    onOpen: _openDetail,
                  ),
                  AppFailureResult(:final error) => AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Consumos de personal',
                    message: error.message,
                  ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(StaffConsumption consumption) async {
    final result = await _repository.getStaffConsumptionItems(consumption.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _StaffConsumptionDetailDialog(
        consumption: consumption,
        result: result,
      ),
    );
  }

  Future<void> _deleteConsumption(StaffConsumption consumption) async {
    final confirmed = await _confirmPermanentDelete(
      context,
      title: 'Eliminar consumo',
      message:
          'Se eliminara permanentemente ${consumption.receiptLabel}, '
          'su detalle y sus movimientos asociados en Supabase.',
    );
    if (!confirmed || !mounted) return;

    final result = await _repository.deleteStaffConsumption(consumption.id);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        setState(() {
          _future = _repository.getStaffConsumptions();
        });
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }
}

class _StaffConsumptionList extends StatelessWidget {
  const _StaffConsumptionList({
    required this.consumptions,
    required this.hasFilter,
    required this.onDelete,
    required this.onOpen,
  });

  final List<StaffConsumption> consumptions;
  final bool hasFilter;
  final ValueChanged<StaffConsumption> onDelete;
  final ValueChanged<StaffConsumption> onOpen;

  @override
  Widget build(BuildContext context) {
    return BackofficeCollectionView<StaffConsumption>(
      items: consumptions,
      rowKey: (item) => item.id,
      rowLabel: (item) => item.receiptLabel,
      selectionActions: [
        BackofficeSelectionAction<StaffConsumption>(
          label: 'Ver detalle',
          icon: Icons.visibility_outlined,
          onPressed: onOpen,
        ),
        BackofficeSelectionAction<StaffConsumption>(
          label: 'Eliminar',
          icon: Icons.delete_outline,
          destructive: true,
          onPressed: onDelete,
        ),
      ],
      searchLabel: 'Buscar empleado o recibo',
      searchTextFor: (item) => [
        item.employeeName,
        item.receiptLabel,
        _dateOnly(item.createdAt),
        _money(item.totalInCents),
      ].join(' '),
      emptyTitle: hasFilter ? 'Sin resultados' : 'Sin consumos',
      emptyMessage: hasFilter
          ? 'No hay consumos que coincidan con la búsqueda.'
          : 'Los consumos registrados desde POS aparecerán aquí.',
      compactBuilder: (context, item) => ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text('${item.receiptLabel} - ${item.employeeName}'),
        subtitle: Text(_date(item.createdAt)),
        trailing: Text(_money(item.totalInCents)),
      ),
      columns: [
        BackofficeListColumn<StaffConsumption>(
          label: 'Recibo',
          width: 210,
          compare: (a, b) => a.receiptLabel.compareTo(b.receiptLabel),
          cell: (_, item) => Text(item.receiptLabel),
        ),
        BackofficeListColumn<StaffConsumption>(
          label: 'Empleado',
          width: 280,
          compare: (a, b) => a.employeeName.compareTo(b.employeeName),
          cell: (_, item) => Text(item.employeeName),
        ),
        BackofficeListColumn<StaffConsumption>(
          label: 'Fecha',
          width: 170,
          compare: (a, b) => a.createdAt.compareTo(b.createdAt),
          cell: (_, item) => Text(_date(item.createdAt)),
        ),
        BackofficeListColumn<StaffConsumption>(
          label: 'Total',
          width: 165,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.totalInCents.compareTo(b.totalInCents),
          cell: (_, item) => Text(_money(item.totalInCents)),
        ),
      ],
    );
  }
}

class _StaffConsumptionDetailDialog extends StatelessWidget {
  const _StaffConsumptionDetailDialog({
    required this.consumption,
    required this.result,
  });

  final StaffConsumption consumption;
  final AppResult<List<StaffConsumptionItem>> result;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${consumption.receiptLabel} - ${consumption.employeeName}'),
      content: SizedBox(
        width: 420,
        child: switch (result) {
          AppSuccess(:final value) => ListView.separated(
            shrinkWrap: true,
            itemCount: value.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = value[index];
              return ListTile(
                title: Text(item.productName),
                subtitle: Text(
                  item.selectedOptionsLabel ?? 'Cantidad: ${item.quantity}',
                ),
                trailing: Text(_money(item.totalInCents)),
              );
            },
          ),
          AppFailureResult(:final error) => Text(error.message),
        },
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
