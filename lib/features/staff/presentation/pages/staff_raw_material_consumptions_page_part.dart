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
  final _search = TextEditingController();
  late DateTime _from;
  late DateTime _to;
  late Future<AppResult<List<RawMaterialStaffConsumption>>> _future;
  String _query = '';

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
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Consumo materia prima',
      actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: _open),
      ],
      body: Column(
        children: [
          _filters(),
          _StaffSearchField(
            controller: _search,
            hintText: 'Buscar empleado, producto, fecha o monto',
            onChanged: (value) => setState(() => _query = value),
          ),
          Expanded(
            child: FutureBuilder<AppResult<List<RawMaterialStaffConsumption>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const AppLoadingPage();
                return switch (snapshot.requireData) {
                  AppSuccess(:final value) => _RawMaterialConsumptionList(
                    items: _filtered(value),
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

  List<RawMaterialStaffConsumption> _filtered(
    List<RawMaterialStaffConsumption> items,
  ) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((item) {
      final products = item.lines.map((line) => line.productName).join(' ');
      final text = [
        item.employeeName,
        products,
        _date(item.consumedAt),
        _money(item.totalInCents),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
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
    if (items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.restaurant_outlined,
        title: 'Sin consumos',
        message: 'Los consumos de materia prima apareceran aqui.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final locked = item.payrollRunId != null;
        return Card(
          child: ListTile(
            leading: Icon(locked ? Icons.lock_outline : Icons.restaurant),
            title: Text('${item.employeeName} - ${_money(item.totalInCents)}'),
            subtitle: Text(
              '${_date(item.consumedAt)} | '
              '${item.lines.length} lineas',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: locked ? 'Aplicado a planilla' : 'Editar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: locked ? null : () => onEdit(item),
                ),
                IconButton(
                  tooltip: locked ? 'Aplicado a planilla' : 'Eliminar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: locked ? null : () => onDelete(item),
                ),
              ],
            ),
            onTap: locked ? null : () => onEdit(item),
          ),
        );
      },
    );
  }
}
