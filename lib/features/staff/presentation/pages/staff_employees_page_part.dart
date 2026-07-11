part of 'staff_admin_pages.dart';

/// Admin employee catalog page.
class StaffPage extends StatefulWidget {
  /// Creates the page.
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  late Future<({List<Employee> employees, List<EmployeePosition> positions})>
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

  Future<({List<Employee> employees, List<EmployeePosition> positions})>
  _load() async {
    final employees = await _repository.getEmployees();
    final positions = await _repository.getPositions();
    return (
      employees: switch (employees) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
      positions: switch (positions) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Personal',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => unawaited(_editEmployee()),
        ),
      ],
      body:
          FutureBuilder<
            ({List<Employee> employees, List<EmployeePosition> positions})
          >(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppEmptyState(
                  icon: Icons.people_outline,
                  message: snapshot.error.toString(),
                  title: 'Personal',
                );
              }
              if (!snapshot.hasData) return const AppLoadingPage();
              final data = snapshot.requireData;
              return _EmployeeList(
                employees: data.employees,
                positions: data.positions,
                onEdit: (employee) => unawaited(_editEmployee(employee)),
              );
            },
          ),
    );
  }

  Future<void> _editEmployee([Employee? employee]) async {
    final data = await _future;
    if (!mounted) return;
    final result = await showDialog<Employee>(
      context: context,
      builder: (_) => _EmployeeDialog(
        employee: employee,
        positions: data.positions,
      ),
    );
    if (result == null || !mounted) return;

    final saved = await _repository.saveEmployee(result);
    if (!mounted) return;
    switch (saved) {
      case AppSuccess():
        setState(_reload);
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }
}

class _EmployeeList extends StatelessWidget {
  const _EmployeeList({
    required this.employees,
    required this.positions,
    required this.onEdit,
  });

  final List<Employee> employees;
  final List<EmployeePosition> positions;
  final ValueChanged<Employee> onEdit;

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return const AppEmptyState(
        icon: Icons.people_outline,
        title: 'Sin personal',
        message: 'Los empleados registrados apareceran aqui.',
      );
    }
    return ListView.separated(
      itemCount: employees.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final employee = employees[index];
        final position = _positionName(employee.positionName, positions);
        return ListTile(
          leading: Icon(
            employee.isActive ? Icons.badge_outlined : Icons.block_outlined,
          ),
          title: Text(employee.fullName),
          subtitle: Text(
            [
              ?position,
              if (employee.code != null) 'No. ${employee.code}',
              'Salario: ${_money(employee.baseSalaryInCents)}',
              if (employee.isActive) 'Activo',
              if (!employee.isActive) 'Inactivo',
            ].join(' - '),
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => onEdit(employee),
        );
      },
    );
  }

  String? _positionName(
    String? positionId,
    List<EmployeePosition> positions,
  ) {
    if (positionId == null) return null;
    for (final position in positions) {
      if (position.id == positionId) return position.name;
    }
    return positionId;
  }
}

class _EmployeeDialog extends StatefulWidget {
  const _EmployeeDialog({required this.positions, this.employee});

  final Employee? employee;
  final List<EmployeePosition> positions;

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  late final _name = TextEditingController(
    text: widget.employee?.fullName ?? '',
  );
  late final _salary = TextEditingController(
    text: ((widget.employee?.baseSalaryInCents ?? 0) / 100).toStringAsFixed(2),
  );
  late String? _positionId = widget.employee?.positionName;
  late bool _active = widget.employee?.isActive ?? true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _salary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.employee == null ? 'Nuevo empleado' : 'Editar empleado',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _positionId,
              decoration: const InputDecoration(labelText: 'Puesto'),
              items: [
                for (final position in widget.positions.where(
                  (position) => position.isActive,
                ))
                  DropdownMenuItem(
                    value: position.id,
                    child: Text(position.name),
                  ),
              ],
              onChanged: (value) => setState(() => _positionId = value),
            ),
            TextField(
              controller: _salary,
              decoration: const InputDecoration(labelText: 'Salario quincenal'),
              keyboardType: TextInputType.number,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }

  void _submit() {
    final name = _name.text.trim();
    final salary = double.tryParse(_salary.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || salary == null || salary < 0) {
      setState(() => _error = 'Verifica nombre y salario.');
      return;
    }
    Navigator.of(context).pop(
      Employee(
        id: widget.employee?.id ?? '',
        code: widget.employee?.code,
        fullName: name,
        positionName: _positionId,
        baseSalaryInCents: (salary * 100).round(),
        isActive: _active,
      ),
    );
  }
}
