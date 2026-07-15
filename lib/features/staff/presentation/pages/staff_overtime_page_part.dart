part of 'staff_admin_pages.dart';

/// Admin page for manual employee overtime entries.
class StaffOvertimePage extends StatefulWidget {
  /// Creates the page.
  const StaffOvertimePage({super.key});

  @override
  State<StaffOvertimePage> createState() => _StaffOvertimePageState();
}

class _StaffOvertimePageState extends State<StaffOvertimePage> {
  final _search = TextEditingController();
  late Future<
    ({
      List<Employee> employees,
      List<EmployeeOvertimeEntry> entries,
      int hourRateInCents,
    })
  >
  _future;
  String _query = '';

  SupabaseStaffAdminRepository get _repository =>
      serviceLocator<SupabaseStaffAdminRepository>();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => _future = _load();

  Future<
    ({
      List<Employee> employees,
      List<EmployeeOvertimeEntry> entries,
      int hourRateInCents,
    })
  >
  _load() async {
    final employees = await _repository.getEmployees();
    final entries = await _repository.getOvertimeEntries();
    final rules = await _repository.getBusinessRules();
    return (
      employees: switch (employees) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
      entries: switch (entries) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
      hourRateInCents: switch (rules) {
        AppSuccess(:final value) => _overtimeRateInCents(value),
        AppFailureResult(:final error) => throw StateError(error.message),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Horas extras',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => unawaited(_openForm()),
        ),
      ],
      body:
          FutureBuilder<
            ({
              List<Employee> employees,
              List<EmployeeOvertimeEntry> entries,
              int hourRateInCents,
            })
          >(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppEmptyState(
                  icon: Icons.more_time_outlined,
                  title: 'Horas extras',
                  message: snapshot.error.toString(),
                );
              }
              if (!snapshot.hasData) return const AppLoadingPage();
              final data = snapshot.requireData;
              return Column(
                children: [
                  _StaffSearchField(
                    controller: _search,
                    hintText: 'Buscar por empleado, fecha, estado o monto',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  Expanded(
                    child: _OvertimeList(
                      entries: _filter(data.entries),
                      hasFilter: _query.trim().isNotEmpty,
                      onDelete: _deleteEntry,
                      onEdit: (entry) => _openForm(entry: entry),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  List<EmployeeOvertimeEntry> _filter(List<EmployeeOvertimeEntry> entries) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return entries;
    return entries.where((entry) {
      final values = [
        entry.employeeName,
        _dateOnly(entry.workedDate),
        _overtimeStatusLabel(entry.status),
        entry.hours.toString(),
        _money(entry.hourRateInCents),
        _money(entry.totalInCents),
        entry.note ?? '',
      ].join(' ').toLowerCase();
      return values.contains(query);
    }).toList();
  }

  Future<void> _openForm({EmployeeOvertimeEntry? entry}) async {
    final data = await _future;
    if (!mounted) return;
    if (data.hourRateInCents <= 0) {
      await showAppMessageDialog(
        context: context,
        message:
            'Primero configura el valor de la hora extra en '
            'Reglas del negocio.',
      );
      if (!mounted) return;
      await Navigator.of(context).pushNamed(AppRoutes.businessRules);
      if (mounted) setState(_reload);
      return;
    }
    final saved = await showDialog<EmployeeOvertimeEntry>(
      context: context,
      builder: (_) => _OvertimeDialog(employees: data.employees, entry: entry),
    );
    if (saved == null || !mounted) return;
    final result = await _repository.saveOvertimeEntry(saved);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        setState(_reload);
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }

  Future<void> _deleteEntry(EmployeeOvertimeEntry entry) async {
    final confirmed = await _confirmPermanentDelete(
      context,
      title: 'Eliminar hora extra',
      message: 'Solo se puede eliminar si todavia no fue pagada.',
    );
    if (!confirmed || !mounted) return;
    final result = await _repository.deleteOvertimeEntry(entry.id);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        setState(_reload);
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }
}

class _OvertimeList extends StatelessWidget {
  const _OvertimeList({
    required this.entries,
    required this.hasFilter,
    required this.onDelete,
    required this.onEdit,
  });

  final List<EmployeeOvertimeEntry> entries;
  final bool hasFilter;
  final ValueChanged<EmployeeOvertimeEntry> onDelete;
  final ValueChanged<EmployeeOvertimeEntry> onEdit;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return AppEmptyState(
        icon: Icons.more_time_outlined,
        title: hasFilter ? 'Sin resultados' : 'Sin horas extras',
        message: hasFilter
            ? 'No hay horas extras que coincidan con la busqueda.'
            : 'Las horas extras registradas apareceran aqui.',
      );
    }
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          leading: const Icon(Icons.more_time_outlined),
          title: Text('${entry.employeeName} - ${entry.hours} h'),
          subtitle: Text(
            [
              _dateOnly(entry.workedDate),
              _overtimeStatusLabel(entry.status),
              'Valor ${_money(entry.hourRateInCents)}',
            ].join(' - '),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_money(entry.totalInCents)),
              if (entry.isPending)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onEdit(entry),
                ),
              if (entry.isPending)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onDelete(entry),
                ),
            ],
          ),
        );
      },
    );
  }
}

String _overtimeStatusLabel(String status) {
  return switch (status) {
    'pending' => 'Pendiente',
    'paid' => 'Pagada',
    _ => status,
  };
}

int _overtimeRateInCents(List<BusinessRule> rules) {
  final rule = rules.where((item) {
    return item.key == BusinessRule.overtimeHourRate;
  }).firstOrNull;
  final value = rule?.textValue?.replaceAll(',', '.') ?? '0';
  return ((double.tryParse(value) ?? 0) * 100).round();
}
