part of 'vacation_requests_page.dart';

/// Backoffice-only vacation register with shared page size and actions.
class _VacationRequestsTable extends StatelessWidget {
  const _VacationRequestsTable({
    required this.items,
    required this.onAction,
  });

  final List<VacationRequest> items;
  final Future<void> Function(VacationRequest, String) onAction;

  String _status(VacationRequest item) => switch (item.status) {
    'pending' => 'Pendiente',
    'approved' => 'Aprobada',
    'rejected' => 'Rechazada',
    _ => item.status,
  };

  @override
  Widget build(BuildContext context) {
    return BackofficeCollectionView<VacationRequest>(
      items: items,
      rowKey: (item) => item.id,
      rowLabel: (item) => item.employeeName,
      selectionActions: [
        BackofficeSelectionAction<VacationRequest>(
          label: 'Aprobar',
          icon: Icons.check_outlined,
          enabledWhen: (item) => item.isPending,
          onPressed: (item) => unawaited(onAction(item, 'approved')),
        ),
        BackofficeSelectionAction<VacationRequest>(
          label: 'Rechazar',
          icon: Icons.close_outlined,
          enabledWhen: (item) => item.isPending,
          onPressed: (item) => unawaited(onAction(item, 'rejected')),
        ),
        BackofficeSelectionAction<VacationRequest>(
          label: 'Eliminar',
          icon: Icons.delete_outline,
          destructive: true,
          onPressed: (item) => unawaited(onAction(item, 'delete')),
        ),
      ],
      searchLabel: 'Buscar empleado, tipo o estado',
      searchTextFor: (item) =>
          '${item.employeeName} ${item.requestType} ${_status(item)} '
          '${item.note ?? ''}',
      emptyTitle: 'Sin resultados',
      emptyMessage: 'No hay vacaciones con esos criterios.',
      compactBuilder: (_, item) =>
          _VacationCard(item: item, onAction: onAction),
      columns: [
        BackofficeListColumn(
          label: 'Empleado',
          width: 285,
          compare: (a, b) => a.employeeName.compareTo(b.employeeName),
          cell: (_, item) => Text(item.employeeName, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Desde',
          width: 140,
          alignment: Alignment.center,
          compare: (a, b) => a.startDate.compareTo(b.startDate),
          cell: (_, item) => Text(_fmt(item.startDate)),
        ),
        BackofficeListColumn(
          label: 'Hasta',
          width: 140,
          alignment: Alignment.center,
          compare: (a, b) => a.endDate.compareTo(b.endDate),
          cell: (_, item) => Text(_fmt(item.endDate)),
        ),
        BackofficeListColumn(
          label: 'Días',
          width: 120,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.requestedDays.compareTo(b.requestedDays),
          cell: (_, item) => Text(item.requestedDays.toStringAsFixed(2)),
        ),
        BackofficeListColumn(
          label: 'Tipo',
          width: 145,
          compare: (a, b) => a.requestType.compareTo(b.requestType),
          cell: (_, item) => Text(
            item.requestType == 'taken' ? 'Tomado' : 'Programado',
          ),
        ),
        BackofficeListColumn(
          label: 'Estado',
          width: 135,
          alignment: Alignment.center,
          compare: (a, b) => a.status.compareTo(b.status),
          cell: (_, item) => Text(_status(item)),
        ),
      ],
    );
  }
}
