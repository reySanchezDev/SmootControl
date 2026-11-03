part of 'attendance_admin_page.dart';

/// Consistent table for administrative marks and read-only mark reports.
class _AttendanceEntriesTable extends StatelessWidget {
  const _AttendanceEntriesTable({
    required this.items,
    required this.readOnly,
    required this.onEdit,
    required this.onCreate,
    required this.onVoid,
  });

  final List<AttendanceEntry> items;
  final bool readOnly;
  final ValueChanged<AttendanceEntry> onEdit;
  final VoidCallback? onCreate;
  final ValueChanged<AttendanceEntry> onVoid;

  @override
  Widget build(BuildContext context) {
    return BackofficeCollectionView<AttendanceEntry>(
      items: items,
      rowKey: readOnly ? null : (entry) => entry.id,
      rowLabel: (entry) => entry.employeeName,
      onCreate: readOnly ? null : onCreate,
      selectionActions: readOnly
          ? null
          : [
              BackofficeSelectionAction<AttendanceEntry>(
                label: 'Editar',
                icon: Icons.edit_outlined,
                onPressed: onEdit,
              ),
              BackofficeSelectionAction<AttendanceEntry>(
                label: 'Eliminar',
                icon: Icons.delete_outline,
                destructive: true,
                onPressed: onVoid,
              ),
            ],
      searchLabel: 'Buscar empleado, fecha, estado o dispositivo',
      searchTextFor: (entry) => [
        entry.employeeName,
        _fmt(entry.workDate),
        _status(entry.status),
        entry.deviceName ?? '',
        entry.workShiftName ?? '',
      ].join(' '),
      emptyTitle: 'Sin resultados',
      emptyMessage: 'No se encontraron marcadas con los criterios indicados.',
      compactBuilder: (_, entry) => _AttendanceEntryCard(
        entry: entry,
        onEdit: readOnly ? null : () => onEdit(entry),
        onVoid: readOnly ? null : () => onVoid(entry),
      ),
      columns: [
        BackofficeListColumn(
          label: 'Empleado',
          width: 285,
          compare: (a, b) => a.employeeName.compareTo(b.employeeName),
          cell: (_, entry) => Text(entry.employeeName, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Fecha',
          width: 135,
          alignment: Alignment.center,
          compare: (a, b) => a.workDate.compareTo(b.workDate),
          cell: (_, entry) => Text(_fmt(entry.workDate)),
        ),
        BackofficeListColumn(
          label: 'Entrada',
          width: 135,
          alignment: Alignment.center,
          compare: (a, b) =>
              _time(a.clockInAt).compareTo(_time(b.clockInAt)),
          cell: (_, entry) => Text(_time(entry.clockInAt)),
        ),
        BackofficeListColumn(
          label: 'Salida',
          width: 135,
          alignment: Alignment.center,
          compare: (a, b) =>
              _time(a.clockOutAt).compareTo(_time(b.clockOutAt)),
          cell: (_, entry) => Text(_time(entry.clockOutAt)),
        ),
        BackofficeListColumn(
          label: 'Turno',
          width: 195,
          compare: (a, b) => (a.workShiftName ?? '')
              .compareTo(b.workShiftName ?? ''),
          cell: (_, entry) =>
              Text(entry.workShiftName ?? '—', softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Estado',
          width: 140,
          alignment: Alignment.center,
          compare: (a, b) => a.status.compareTo(b.status),
          cell: (_, entry) => Text(_status(entry.status)),
        ),

      ],
    );
  }
}
