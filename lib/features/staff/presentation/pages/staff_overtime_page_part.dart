part of 'staff_admin_pages.dart';

/// Admin page for manual employee overtime entries.
class StaffOvertimePage extends StatefulWidget {
  /// Creates the page.
  const StaffOvertimePage({super.key});

  @override
  State<StaffOvertimePage> createState() => _StaffOvertimePageState();
}

class _StaffOvertimePageState extends State<StaffOvertimePage> {
  late Future<
    ({
      List<Employee> employees,
      List<EmployeeOvertimeEntry> entries,
      int hourRateInCents,
    })
  >
  _future;

  SupabaseStaffAdminRepository get _repository =>
      serviceLocator<SupabaseStaffAdminRepository>();

  @override
  void initState() {
    super.initState();
    _reload();
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
        BackofficeNewAction(
          label: 'Nueva hora extra',
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
                  Expanded(
                    child: _OvertimeList(
                      entries: data.entries,
                      hasFilter: false,
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
    return BackofficeCollectionView<EmployeeOvertimeEntry>(
      items: entries,
      rowKey: (entry) => entry.id,
      rowLabel: (entry) => entry.employeeName,
      selectionActions: [
        BackofficeSelectionAction<EmployeeOvertimeEntry>(
          label: 'Editar',
          icon: Icons.edit_outlined,
          enabledWhen: (entry) => entry.isPending,
          onPressed: onEdit,
        ),
        BackofficeSelectionAction<EmployeeOvertimeEntry>(
          label: 'Eliminar',
          icon: Icons.delete_outline,
          destructive: true,
          enabledWhen: (entry) => entry.isPending,
          onPressed: onDelete,
        ),
      ],
      searchLabel: 'Buscar horas extra',
      searchTextFor: (entry) => [
        entry.employeeName,
        _dateOnly(entry.workedDate),
        _overtimeStatusLabel(entry.status),
        entry.hours.toString(),
        _money(entry.hourRateInCents),
        _money(entry.totalInCents),
        entry.note ?? '',
      ].join(' '),
      emptyTitle: hasFilter ? 'Sin resultados' : 'Sin horas extras',
      emptyMessage: hasFilter
          ? 'No hay horas extras que coincidan con la búsqueda.'
          : 'Las horas extras registradas aparecerán aquí.',
      compactBuilder: (_, entry) => ListTile(
        leading: const Icon(Icons.more_time_outlined),
        title: Text(entry.employeeName),
        subtitle: Text(
          '${_dateOnly(entry.workedDate)} · '
          '${_overtimeStatusLabel(entry.status)} · '
          '${entry.hours.toStringAsFixed(2)} h',
        ),
        trailing: Text(_money(entry.totalInCents)),
      ),
      columns: [
        BackofficeListColumn<EmployeeOvertimeEntry>(
          label: 'Empleado',
          width: 260,
          compare: (a, b) => a.employeeName.compareTo(b.employeeName),
          cell: (_, entry) => Text(entry.employeeName),
        ),
        BackofficeListColumn<EmployeeOvertimeEntry>(
          label: 'Fecha',
          width: 165,
          compare: (a, b) => a.workedDate.compareTo(b.workedDate),
          cell: (_, entry) => Text(_dateOnly(entry.workedDate)),
        ),
        BackofficeListColumn<EmployeeOvertimeEntry>(
          label: 'Horas',
          width: 120,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.hours.compareTo(b.hours),
          cell: (_, entry) => Text(entry.hours.toStringAsFixed(2)),
        ),
        BackofficeListColumn<EmployeeOvertimeEntry>(
          label: 'Estado',
          width: 150,
          compare: (a, b) => a.status.compareTo(b.status),
          cell: (_, entry) => Text(_overtimeStatusLabel(entry.status)),
        ),
        BackofficeListColumn<EmployeeOvertimeEntry>(
          label: 'Monto',
          width: 170,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.totalInCents.compareTo(b.totalInCents),
          cell: (_, entry) => Text(_money(entry.totalInCents)),
        ),
      ],
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
