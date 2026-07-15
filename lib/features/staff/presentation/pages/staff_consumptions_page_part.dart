part of 'staff_admin_pages.dart';

/// Admin page for staff consumption receipts.
class StaffConsumptionsPage extends StatefulWidget {
  /// Creates the page.
  const StaffConsumptionsPage({super.key});

  @override
  State<StaffConsumptionsPage> createState() => _StaffConsumptionsPageState();
}

class _StaffConsumptionsPageState extends State<StaffConsumptionsPage> {
  final _searchController = TextEditingController();
  late Future<AppResult<List<StaffConsumption>>> _future;
  String _query = '';

  SupabaseStaffAdminRepository get _repository =>
      serviceLocator<SupabaseStaffAdminRepository>();

  @override
  void initState() {
    super.initState();
    _future = _repository.getStaffConsumptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Consumos de personal',
      body: Column(
        children: [
          _StaffSearchField(
            controller: _searchController,
            hintText: 'Buscar por empleado, recibo, fecha o monto',
            onChanged: (value) => setState(() => _query = value),
          ),
          Expanded(
            child: FutureBuilder<AppResult<List<StaffConsumption>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const AppLoadingPage();
                return switch (snapshot.requireData) {
                  AppSuccess(:final value) => _StaffConsumptionList(
                    consumptions: _filterConsumptions(value),
                    hasFilter: _query.trim().isNotEmpty,
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

  List<StaffConsumption> _filterConsumptions(
    List<StaffConsumption> consumptions,
  ) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return consumptions;
    return consumptions.where((item) {
      final values = [
        item.employeeName,
        item.receiptLabel,
        _dateOnly(item.createdAt),
        _money(item.totalInCents),
      ].join(' ').toLowerCase();
      return values.contains(query);
    }).toList();
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
    if (consumptions.isEmpty) {
      return AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: hasFilter ? 'Sin resultados' : 'Sin consumos',
        message: hasFilter
            ? 'No hay consumos que coincidan con la busqueda.'
            : 'Los consumos registrados desde POS apareceran aqui.',
      );
    }
    return ListView.separated(
      itemCount: consumptions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = consumptions[index];
        return ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: Text('${item.receiptLabel} - ${item.employeeName}'),
          subtitle: Text(_date(item.createdAt)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_money(item.totalInCents)),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDelete(item),
              ),
            ],
          ),
          onTap: () => onOpen(item),
        );
      },
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

class _StaffSearchField extends StatelessWidget {
  const _StaffSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
