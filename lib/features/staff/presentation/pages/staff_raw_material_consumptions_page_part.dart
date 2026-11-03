part of 'staff_admin_pages.dart';

/// Admin list for employee raw-material consumptions.
class RawMaterialConsumptionsPage extends StatefulWidget {
  /// Creates the page.
  const RawMaterialConsumptionsPage({super.key});

  @override
  State<RawMaterialConsumptionsPage> createState() =>
      _RawMaterialConsumptionsPageState();
}

class _RawMaterialConsumptionsPageState
    extends State<RawMaterialConsumptionsPage> {
  late DateTime _from;
  late DateTime _to;
  late Future<AppResult<List<RawMaterialStaffConsumption>>> _future;

  SupabaseStaffAdminRepository get _staff =>
      serviceLocator<SupabaseStaffAdminRepository>();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month);
    _to = DateTime(now.year, now.month + 1, 0);
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Consumo materia prima',
      actions: [
        BackofficeNewAction(
          label: 'Nuevo consumo',
          onPressed: _open,
        ),
      ],
      body: Column(
        children: [
          _filters(),
          Expanded(
            child: FutureBuilder<AppResult<List<RawMaterialStaffConsumption>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const AppLoadingPage();
                return switch (snapshot.requireData) {
                  AppSuccess(:final value) => _RawMaterialConsumptionList(
                    items: value,
                    onDelete: _delete,
                    onEdit: _open,
                  ),
                  AppFailureResult(:final error) => AppEmptyState(
                    icon: Icons.restaurant_outlined,
                    title: 'Consumo materia prima',
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

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(child: _dateButton('Desde ${_dateOnly(_from)}', true)),
          const SizedBox(width: 8),
          Expanded(child: _dateButton('Hasta ${_dateOnly(_to)}', false)),
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _future = _load()),
          ),
        ],
      ),
    );
  }

  Widget _dateButton(String label, bool isFrom) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.calendar_month_outlined),
      label: Text(label, overflow: TextOverflow.ellipsis),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: isFrom ? _from : _to,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked == null) return;
        setState(() {
          if (isFrom) {
            _from = picked;
          } else {
            _to = picked;
          }
          _future = _load();
        });
      },
    );
  }

  Future<AppResult<List<RawMaterialStaffConsumption>>> _load() {
    return _staff.getRawMaterialStaffConsumptions(from: _from, to: _to);
  }

  Future<void> _open([RawMaterialStaffConsumption? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RawMaterialConsumptionDialog(consumption: item),
    );
    if (saved ?? false) setState(() => _future = _load());
  }

  Future<void> _delete(RawMaterialStaffConsumption item) async {
    final confirmed = await _confirmPermanentDelete(
      context,
      title: 'Eliminar consumo',
      message: 'Se eliminara permanentemente este consumo y su inventario.',
    );
    if (!confirmed || !mounted) return;
    final result = await _staff.deleteRawMaterialStaffConsumption(item.id);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        setState(() => _future = _load());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consumo eliminado.')),
        );
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }
}

class _RawMaterialConsumptionList extends StatelessWidget {
  const _RawMaterialConsumptionList({
    required this.items,
    required this.onDelete,
    required this.onEdit,
  });

  final List<RawMaterialStaffConsumption> items;
  final ValueChanged<RawMaterialStaffConsumption> onDelete;
  final ValueChanged<RawMaterialStaffConsumption> onEdit;

  @override
  Widget build(BuildContext context) {
    return BackofficeCollectionView<RawMaterialStaffConsumption>(
      items: items,
      rowKey: (item) => item.id,
      rowLabel: (item) => item.employeeName,
      selectionActions: [
        BackofficeSelectionAction<RawMaterialStaffConsumption>(
          label: 'Editar',
          icon: Icons.edit_outlined,
          enabledWhen: (item) => item.payrollRunId == null,
          onPressed: onEdit,
        ),
        BackofficeSelectionAction<RawMaterialStaffConsumption>(
          label: 'Eliminar',
          icon: Icons.delete_outline,
          destructive: true,
          enabledWhen: (item) => item.payrollRunId == null,
          onPressed: onDelete,
        ),
      ],
      searchLabel: 'Buscar consumo de materia prima',
      searchTextFor: (item) => [
        item.employeeName,
        _date(item.consumedAt),
        _money(item.totalInCents),
        for (final line in item.lines) line.productName,
      ].join(' '),
      emptyTitle: 'Sin consumos',
      emptyMessage: 'Los consumos de materia prima aparecerán aquí.',
      compactBuilder: (_, item) => ListTile(
        leading: Icon(
          item.payrollRunId == null
              ? Icons.restaurant_outlined
              : Icons.lock_outline,
        ),
        title: Text(item.employeeName),
        subtitle: Text(
          '${_date(item.consumedAt)} · ${item.lines.length} líneas',
        ),
        trailing: Text(_money(item.totalInCents)),
      ),
      columns: [
        BackofficeListColumn<RawMaterialStaffConsumption>(
          label: 'Empleado',
          width: 260,
          compare: (a, b) => a.employeeName.compareTo(b.employeeName),
          cell: (_, item) => Text(item.employeeName),
        ),
        BackofficeListColumn<RawMaterialStaffConsumption>(
          label: 'Fecha',
          width: 175,
          compare: (a, b) => a.consumedAt.compareTo(b.consumedAt),
          cell: (_, item) => Text(_date(item.consumedAt)),
        ),
        BackofficeListColumn<RawMaterialStaffConsumption>(
          label: 'Líneas',
          width: 120,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.lines.length.compareTo(b.lines.length),
          cell: (_, item) => Text('${item.lines.length}'),
        ),
        BackofficeListColumn<RawMaterialStaffConsumption>(
          label: 'Estado',
          width: 170,
          cell: (_, item) => Text(
            item.payrollRunId == null ? 'Editable' : 'Aplicado a planilla',
          ),
        ),
        BackofficeListColumn<RawMaterialStaffConsumption>(
          label: 'Monto',
          width: 170,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.totalInCents.compareTo(b.totalInCents),
          cell: (_, item) => Text(_money(item.totalInCents)),
        ),
      ],
    );
  }
}
