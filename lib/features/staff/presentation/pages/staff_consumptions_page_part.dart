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
      body: FutureBuilder<AppResult<List<StaffConsumption>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const AppLoadingPage();
          return switch (snapshot.requireData) {
            AppSuccess(:final value) => _StaffConsumptionList(
              consumptions: value,
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
    required this.onDelete,
    required this.onOpen,
  });

  final List<StaffConsumption> consumptions;
  final ValueChanged<StaffConsumption> onDelete;
  final ValueChanged<StaffConsumption> onOpen;

  @override
  Widget build(BuildContext context) {
    if (consumptions.isEmpty) {
      return const AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Sin consumos',
        message: 'Los consumos registrados desde POS apareceran aqui.',
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
