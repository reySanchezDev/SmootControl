part of 'staff_admin_pages.dart';

/// Admin page for salary advances.
class SalaryAdvancesPage extends StatefulWidget {
  /// Creates the page.
  const SalaryAdvancesPage({super.key});

  @override
  State<SalaryAdvancesPage> createState() => _SalaryAdvancesPageState();
}

class _SalaryAdvancesPageState extends State<SalaryAdvancesPage> {
  static const _activeStatuses = ['pending', 'partially_paid'];

  final _searchController = TextEditingController();
  late Future<({List<Employee> employees, List<SalaryAdvance> advances})>
  _future;
  late DateTime _from;
  String _query = '';
  late DateTime _to;

  SupabaseStaffAdminRepository get _repository =>
      serviceLocator<SupabaseStaffAdminRepository>();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month);
    _to = DateTime(now.year, now.month, now.day);
    _reload();
  }

  void _reload() {
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<({List<Employee> employees, List<SalaryAdvance> advances})>
  _load() async {
    final employees = await _repository.getEmployees();
    final advances = await _repository.getSalaryAdvances(
      from: _from,
      statuses: _activeStatuses,
      to: _to,
    );
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
              return Column(
                children: [
                  _SalaryAdvanceRangeFilter(
                    from: _from,
                    onChanged: _selectRange,
                    onMonth: _selectCurrentMonth,
                    onReload: () => setState(_reload),
                    to: _to,
                  ),
                  _StaffSearchField(
                    controller: _searchController,
                    hintText: 'Buscar por empleado, fecha, estado o monto',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  Expanded(
                    child: _SalaryAdvanceList(
                      advances: _filterAdvances(data),
                      employees: data.employees,
                      hasFilter: _query.trim().isNotEmpty,
                      onDelete: _deleteAdvance,
                    ),
                  ),
                ],
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

  List<SalaryAdvance> _filterAdvances(
    ({List<Employee> employees, List<SalaryAdvance> advances}) data,
  ) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return data.advances;
    final employeeById = {for (final item in data.employees) item.id: item};
    return data.advances.where((advance) {
      final employee = employeeById[advance.employeeId];
      final balance = advance.balanceInCents ?? advance.amountInCents;
      final paid = advance.amountInCents - balance;
      final values = [
        employee?.fullName ?? 'Empleado',
        employee?.code ?? '',
        _dateOnly(advance.deliveredAt),
        if (advance.affectsCash) 'Afecta caja',
        if (!advance.affectsCash) 'Cuenta externa',
        _salaryAdvanceStatusLabel(advance.status),
        _money(advance.amountInCents),
        _money(paid),
        _money(balance),
        advance.note ?? '',
      ].join(' ').toLowerCase();
      return values.contains(query);
    }).toList();
  }

  void _selectCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _from = DateTime(now.year, now.month);
      _to = DateTime(now.year, now.month, now.day);
      _reload();
    });
  }

  void _selectRange(DateTimeRange range) {
    setState(() {
      _from = range.start;
      _to = range.end;
      _reload();
    });
  }
}
