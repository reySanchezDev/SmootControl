part of 'pilot_operation_reset_page.dart';

extension _PilotOperationResetActions on _PilotOperationResetPageState {
  Future<void> _loadDevices() async {
    final result = await serviceLocator<PilotOperationResetService>()
        .listDevicesForCleanup();
    if (!mounted) return;
    result.when(
      success: (devices) {
        _updateState(() {
          _devices = devices;
          if (!_devices.any((device) => device.id == _selectedDeviceId)) {
            _selectedDeviceId = _devices.isEmpty ? null : _devices.first.id;
          }
        });
      },
      failure: (_) {},
    );
  }

  Future<void> _runDeviceCleanup() async {
    final deviceId = _selectedDeviceId;
    if (deviceId == null) return;
    final confirmation = await _askConfirmation(
      confirmationText: 'BORRAR DISPOSITIVO',
      title: 'Limpiar pruebas por dispositivo',
    );
    if (confirmation == null || !mounted) return;

    _updateState(() => _busyAction = 'pos_device');
    final result = await serviceLocator<PilotOperationResetService>()
        .cleanupDeviceTestData(
          confirmation: confirmation,
          deviceId: deviceId,
        );
    if (!mounted) return;
    _updateState(() => _busyAction = null);
    await _showResult(
      successTitle: 'Dispositivo limpiado',
      result: result,
    );
    await _loadDevices();
  }

  Future<void> _renameSelectedDevice() async {
    final device = _selectedDevice();
    if (device == null) return;
    final controller = TextEditingController(text: device.name);
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Renombrar dispositivo'),
            content: AppInput(
              controller: controller,
              label: 'Nombre visible',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text.trim()),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      );
      if (name == null || name.trim().length < 2 || !mounted) return;
      _updateState(() => _busyAction = 'rename_pos_device');
      final result = await serviceLocator<PilotOperationResetService>()
          .renameDevice(deviceId: device.id, name: name);
      if (!mounted) return;
      _updateState(() => _busyAction = null);
      await result.when(
        success: (_) async {
          await showAppMessageDialog(
            context: context,
            title: 'Dispositivo actualizado',
            message: 'El nombre del dispositivo se guardo correctamente.',
          );
          await _loadDevices();
        },
        failure: (failure) {
          return showAppMessageDialog(
            context: context,
            title: 'No se pudo guardar',
            message: failure.cause == null
                ? failure.message
                : '${failure.message}\n\nDetalle: ${failure.cause}',
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  PosDeviceCleanupCandidate? _selectedDevice() {
    for (final device in _devices) {
      if (device.id == _selectedDeviceId) return device;
    }
    return null;
  }

  Future<void> _runScope(PilotCleanupScope scope) async {
    final confirmation = await _askConfirmation(
      confirmationText: scope.confirmationText,
      title: _scopeTitle(scope),
    );
    if (confirmation == null || !mounted) return;

    _updateState(() => _busyAction = scope.remoteValue);
    final result = await serviceLocator<PilotOperationResetService>()
        .resetScope(scope: scope, confirmation: confirmation);
    if (!mounted) return;
    _updateState(() => _busyAction = null);

    await _showResult(successTitle: 'Limpieza completada', result: result);
  }

  Future<void> _runFullReset() async {
    final confirmation = await _askConfirmation(
      confirmationText: PilotOperationResetService.confirmationText,
      title: 'Reiniciar produccion',
    );
    if (confirmation == null || !mounted) return;

    _updateState(() => _busyAction = 'full_reset');
    final result = await serviceLocator<PilotOperationResetService>()
        .resetPilotOperation(confirmation: confirmation);
    if (!mounted) return;
    _updateState(() => _busyAction = null);

    await _showResult(successTitle: 'Reinicio completado', result: result);
  }

  Future<String?> _askConfirmation({
    required String confirmationText,
    required String title,
  }) async {
    final controller = TextEditingController();
    try {
      return showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final canSubmit = controller.text.trim() == confirmationText;
              return AlertDialog(
                title: Text(title),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText(
                      'Esta accion es irreversible. Para continuar escribe:',
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      confirmationText,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      controller: controller,
                      label: 'Confirmacion',
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: canSubmit
                        ? () => Navigator.of(
                            dialogContext,
                          ).pop(controller.text.trim())
                        : null,
                    child: const Text('Ejecutar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showResult({
    required AppResult<PilotOperationResetSummary> result,
    required String successTitle,
  }) {
    return result.when(
      success: (summary) {
        return showAppMessageDialog(
          context: context,
          title: successTitle,
          message:
              'Local: ${summary.localRows} registros procesados.\n'
              'Remoto: ${summary.remoteRows} registros procesados.',
        );
      },
      failure: (failure) {
        return showAppMessageDialog(
          context: context,
          title: 'No se pudo completar',
          message: failure.cause == null
              ? failure.message
              : '${failure.message}\n\nDetalle: ${failure.cause}',
        );
      },
    );
  }

  String _scopeTitle(PilotCleanupScope scope) {
    return switch (scope) {
      PilotCleanupScope.sales => 'Limpiar ventas POS',
      PilotCleanupScope.expenses => 'Limpiar gastos',
      PilotCleanupScope.salaryAdvances => 'Limpiar adelantos',
      PilotCleanupScope.payroll => 'Limpiar planilla',
      PilotCleanupScope.staffConsumptions => 'Limpiar consumos de personal',
      PilotCleanupScope.staffOperations => 'Limpiar personal operativo',
    };
  }
}
