part of 'staff_admin_pages.dart';

/// Admin page for salary advances.
class SalaryAdvancesPage extends StatefulWidget {
  /// Creates the page.
  const SalaryAdvancesPage({super.key});

  @override
  State<SalaryAdvancesPage> createState() => _SalaryAdvancesPageState();
}

class _SalaryAdvancesPageState extends State<SalaryAdvancesPage> {
  late Future<({List<Employee> employees, List<SalaryAdvance> advances})>
  _future;

  SupabaseStaffAdminRepository get _repository =>
      serviceLocator<SupabaseStaffAdminRepository>();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _load();
  }

  Future<({List<Employee> employees, List<SalaryAdvance> advances})>
  _load() async {
    final employees = await _repository.getEmployees();
    final advances = await _repository.getSalaryAdvances();
    return (
      employees: switch (employees) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
      advances: switch (advances) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Adelantos',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => unawaited(_addAdvance()),
        ),
      ],
      body:
          FutureBuilder<
            ({List<Employee> employees, List<SalaryAdvance> advances})
          >(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppEmptyState(
                  icon: Icons.payments_outlined,
                  title: 'Adelantos',
                  message: snapshot.error.toString(),
                );
              }
              if (!snapshot.hasData) return const AppLoadingPage();
              final data = snapshot.requireData;
              return _SalaryAdvanceList(
                advances: data.advances,
                employees: data.employees,
                onDelete: _deleteAdvance,
              );
            },
          ),
    );
  }

  Future<void> _addAdvance() async {
    final data = await _future;
    if (!mounted) return;
    final advance = await showDialog<SalaryAdvance>(
      context: context,
      builder: (_) => _SalaryAdvanceDialog(employees: data.employees),
    );
    if (advance == null || !mounted) return;
    final result = await _repository.saveSalaryAdvance(advance);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        setState(_reload);
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }

  Future<void> _deleteAdvance(SalaryAdvance advance) async {
    final confirmed = await _confirmPermanentDelete(
      context,
      title: 'Eliminar adelanto',
      message:
          'Se eliminara permanentemente este adelanto en Supabase. '
          'Si ya tiene abonos de planilla, Supabase lo rechazara.',
    );
    if (!confirmed || !mounted) return;

    final result = await _repository.deleteSalaryAdvance(advance.id);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        setState(_reload);
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }
}

class _SalaryAdvanceList extends StatelessWidget {
  const _SalaryAdvanceList({
    required this.advances,
    required this.employees,
    required this.onDelete,
  });

  final List<SalaryAdvance> advances;
  final List<Employee> employees;
  final ValueChanged<SalaryAdvance> onDelete;

  @override
  Widget build(BuildContext context) {
    if (advances.isEmpty) {
      return const AppEmptyState(
        icon: Icons.payments_outlined,
        title: 'Sin adelantos',
        message: 'Los adelantos registrados apareceran aqui.',
      );
    }
    final employeeById = {
      for (final employee in employees) employee.id: employee,
    };
    return ListView.separated(
      itemCount: advances.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final advance = advances[index];
        final employee = employeeById[advance.employeeId];
        final balance = advance.balanceInCents ?? advance.amountInCents;
        final paid = advance.amountInCents - balance;
        return ListTile(
          leading: Icon(
            advance.affectsCash
                ? Icons.point_of_sale_outlined
                : Icons.account_balance_outlined,
          ),
          title: Text(employee?.fullName ?? 'Empleado'),
          subtitle: Text(
            [
              'Entrega: ${_dateOnly(advance.deliveredAt)}',
              if (advance.affectsCash) 'Afecta caja',
              if (!advance.affectsCash) 'Cuenta externa',
              _advanceStatusLabel(advance.status),
              'Adelanto: ${_money(advance.amountInCents)}',
              'Abonado: ${_money(paid)}',
              'Saldo: ${_money(balance)}',
            ].join(' - '),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_money(balance)),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDelete(advance),
              ),
            ],
          ),
        );
      },
    );
  }

  String _advanceStatusLabel(String status) {
    return switch (status) {
      'pending' => 'Pendiente',
      'partially_paid' => 'Parcial',
      'paid' => 'Pagado',
      _ => status,
    };
  }
}
