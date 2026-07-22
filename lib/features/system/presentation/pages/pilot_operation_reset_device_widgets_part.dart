part of 'pilot_operation_reset_page.dart';

class _DeviceCleanupCard extends StatelessWidget {
  const _DeviceCleanupCard({
    required this.busy,
    required this.devices,
    required this.onRefresh,
    required this.onRename,
    required this.onRun,
    required this.onSelected,
    required this.selectedDeviceId,
  });

  final bool busy;
  final List<PosDeviceCleanupCandidate> devices;
  final VoidCallback onRefresh;
  final VoidCallback onRename;
  final VoidCallback onRun;
  final ValueChanged<String?> onSelected;
  final String? selectedDeviceId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _selectedDevice();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DeviceCleanupHeader(
              busy: busy,
              colorScheme: colorScheme,
              canRename: selected != null,
              onRefresh: onRefresh,
              onRename: onRename,
            ),
            const SizedBox(height: 8),
            const AppText(
              'Borra solo ventas, caja, gastos, adelantos y movimientos '
              'creados por el POS seleccionado. Tambien borra marcadas '
              'y horas extra pendientes del marcador.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              variant: AppTextVariant.label,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: selectedDeviceId,
              decoration: const InputDecoration(labelText: 'Dispositivo POS'),
              menuMaxHeight: 340,
              items: [
                for (final device in devices)
                  DropdownMenuItem(
                    value: device.id,
                    child: Text(
                      _deviceLabel(device),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: busy ? null : onSelected,
            ),
            const SizedBox(height: 10),
            _DeviceCleanupFooter(
              busy: busy,
              onRun: onRun,
              selected: selected,
            ),
          ],
        ),
      ),
    );
  }

  PosDeviceCleanupCandidate? _selectedDevice() {
    for (final device in devices) {
      if (device.id == selectedDeviceId) return device;
    }
    return null;
  }

  String _deviceLabel(PosDeviceCleanupCandidate device) {
    final marker = device.isCurrentDevice ? ' - este dispositivo' : '';
    return '${device.name}$marker (${device.totalRows})';
  }
}

class _DeviceCleanupHeader extends StatelessWidget {
  const _DeviceCleanupHeader({
    required this.busy,
    required this.canRename,
    required this.colorScheme,
    required this.onRefresh,
    required this.onRename,
  });

  final bool busy;
  final bool canRename;
  final ColorScheme colorScheme;
  final VoidCallback onRefresh;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.phone_android_outlined, color: colorScheme.primary),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: AppText(
            'Limpiar pruebas por dispositivo',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            variant: AppTextVariant.titleMedium,
          ),
        ),
        IconButton(
          onPressed: busy || !canRename ? null : onRename,
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Renombrar',
        ),
        IconButton(
          onPressed: busy ? null : onRefresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Recargar dispositivos',
        ),
      ],
    );
  }
}

class _DeviceCleanupFooter extends StatelessWidget {
  const _DeviceCleanupFooter({
    required this.busy,
    required this.onRun,
    required this.selected,
  });

  final bool busy;
  final VoidCallback onRun;
  final PosDeviceCleanupCandidate? selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppText(
            selected == null
                ? 'No hay dispositivos con datos trazables.'
                : selected!.isCurrentDevice
                ? 'Este dispositivo: ${selected!.totalRows} registros'
                : 'Registros trazables: ${selected!.totalRows}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            variant: AppTextVariant.label,
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: busy || selected == null ? null : onRun,
          icon: busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cleaning_services_outlined),
          label: const Text('Limpiar'),
        ),
      ],
    );
  }
}
