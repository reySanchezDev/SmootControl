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

  late Future<({List<Employee> employees, List<SalaryAdvance> advances})>
  _future;
  late DateTime _from;
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
                  Expanded(
                    child: _SalaryAdvanceList(
                      advances: data.advances,
                      employees: data.employees,
                      hasFilter: false,
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
