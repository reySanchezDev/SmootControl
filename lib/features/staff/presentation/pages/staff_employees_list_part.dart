part of 'staff_admin_pages.dart';

/// Consistent employee listing, restricted to administrative pages.
class _EmployeeList extends StatelessWidget {
  const _EmployeeList({
    required this.employees,
    required this.positions,
    required this.shifts,
    required this.onEdit,
  });

  final List<Employee> employees;
  final List<EmployeePosition> positions;
  final List<EmployeeWorkShift> shifts;
  final ValueChanged<Employee> onEdit;

  String _positionName(String? id) {
    if (id == null) return '—';
    for (final item in positions) {
      if (item.id == id) return item.name;
    }
    return id;
  }

  String _shiftName(String? id) {
    if (id == null) return '—';
    for (final item in shifts) {
      if (item.id == id) return item.name;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return BackofficeCollectionView<Employee>(
      items: employees,
      searchLabel: 'Buscar empleado, código, puesto o turno',
      searchTextFor: (employee) => [
        employee.fullName,
        employee.code ?? '',
        _positionName(employee.positionName),
        _shiftName(employee.workShiftId),
        employee.isActive ? 'activo' : 'inactivo',
      ].join(' '),
      emptyTitle: 'Sin resultados',
      emptyMessage: 'No hay empleados que coincidan con la búsqueda.',
      compactBuilder: (_, employee) => Card(
        child: ListTile(
          leading: Icon(
            employee.isActive
                ? Icons.badge_outlined
                : Icons.block_outlined,
          ),
          title: Text(employee.fullName, softWrap: true),
          subtitle: Text([
            _positionName(employee.positionName),
            _shiftName(employee.workShiftId),
            if (employee.code != null) 'No. ${employee.code}',
            employee.isActive ? 'Activo' : 'Inactivo',
          ].join(' · '), softWrap: true),
          trailing: IconButton(
            tooltip: 'Editar empleado',
            onPressed: () => onEdit(employee),
            icon: const Icon(Icons.edit_outlined),
          ),
        ),
      ),
      columns: [
        BackofficeListColumn(
          label: 'Empleado',
          width: 290,
          compare: (a, b) => a.fullName.compareTo(b.fullName),
          cell: (_, employee) => Text(employee.fullName, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Código',
          width: 130,
          compare: (a, b) => (a.code ?? '').compareTo(b.code ?? ''),
          cell: (_, employee) => Text(employee.code ?? '—'),
        ),
        BackofficeListColumn(
          label: 'Puesto',
          width: 225,
          compare: (a, b) => _positionName(a.positionName)
              .compareTo(_positionName(b.positionName)),
          cell: (_, employee) =>
              Text(_positionName(employee.positionName), softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Turno',
          width: 225,
          compare: (a, b) => _shiftName(a.workShiftId)
              .compareTo(_shiftName(b.workShiftId)),
          cell: (_, employee) =>
              Text(_shiftName(employee.workShiftId), softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Salario',
          width: 160,
          alignment: Alignment.centerRight,
          compare: (a, b) =>
              a.baseSalaryInCents.compareTo(b.baseSalaryInCents),
          cell: (_, employee) =>
              Text(_money(employee.baseSalaryInCents)),
        ),
        BackofficeListColumn(
          label: 'Estado',
          width: 140,
          alignment: Alignment.center,
          compare: (a, b) => (a.isActive ? 1 : 0)
              .compareTo(b.isActive ? 1 : 0),
          cell: (_, employee) =>
              Text(employee.isActive ? 'Activo' : 'Inactivo'),
        ),
        BackofficeListColumn(
          label: 'Acciones',
          width: 160,
          alignment: Alignment.center,
          cell: (_, employee) => TextButton.icon(
            onPressed: () => onEdit(employee),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar'),
          ),
        ),
      ],
    );
  }
}
