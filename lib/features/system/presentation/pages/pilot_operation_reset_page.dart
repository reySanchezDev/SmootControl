import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/features/system/data/services/pilot_operation_reset_service.dart';

/// Administrative utilities for controlled operational resets.
class PilotOperationResetPage extends StatefulWidget {
  /// Creates the system utilities page.
  const PilotOperationResetPage({super.key});

  @override
  State<PilotOperationResetPage> createState() =>
      _PilotOperationResetPageState();
}

class _PilotOperationResetPageState extends State<PilotOperationResetPage> {
  final _confirmationController = TextEditingController();
  bool _isBusy = false;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppPageScaffold(
      title: 'Utilidades',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cleaning_services_outlined,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: AppText(
                            'Cierre de piloto',
                            variant: AppTextVariant.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const AppText(
                      'Esta opcion elimina movimientos de prueba sin borrar '
                      'catalogos, usuarios ni configuracion.',
                    ),
                    const SizedBox(height: 12),
                    const _ResetScopeList(),
                    const SizedBox(height: 16),
                    AppInput(
                      controller: _confirmationController,
                      label:
                          'Escribe '
                          '${PilotOperationResetService.confirmationText}',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          foregroundColor: colorScheme.onError,
                        ),
                        onPressed: _canSubmit ? _confirmAndRun : null,
                        icon: _isBusy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Reiniciar movimientos'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canSubmit {
    return !_isBusy &&
        _confirmationController.text.trim() ==
            PilotOperationResetService.confirmationText;
  }

  Future<void> _confirmAndRun() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar cierre de piloto'),
          content: const Text(
            'Se eliminaran ventas, cajas, gastos, tickets abiertos, cola de '
            'sincronizacion y movimientos de inventario/empaque. Los '
            'catalogos se conservaran y el stock quedara en cero.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Ejecutar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _isBusy = true);
    final result = await serviceLocator<PilotOperationResetService>()
        .resetPilotOperation(confirmation: _confirmationController.text);
    if (!mounted) return;
    setState(() => _isBusy = false);

    await result.when(
      success: (summary) async {
        _confirmationController.clear();
        await showAppMessageDialog(
          context: context,
          title: 'Cierre completado',
          message:
              'Movimientos de prueba eliminados correctamente.\n\n'
              'Remoto: ${summary.remoteRows} registros procesados.\n'
              'Local: ${summary.localRows} registros eliminados.\n\n'
              'Inventarios, empaques y consecutivo quedaron listos para '
              'cargar datos reales de produccion.',
        );
      },
      failure: (failure) async {
        await showAppMessageDialog(
          context: context,
          title: 'No se pudo completar',
          message: failure.cause == null
              ? failure.message
              : '${failure.message}\n\nDetalle: ${failure.cause}',
        );
      },
    );
  }
}

class _ResetScopeList extends StatelessWidget {
  const _ResetScopeList();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScopeRow(
              icon: Icons.check_circle_outline,
              text: 'Conserva productos, categorias, usuarios, permisos y POS.',
            ),
            _ScopeRow(
              icon: Icons.delete_outline,
              text: 'Elimina ventas, cajas, gastos y tickets abiertos.',
            ),
            _ScopeRow(
              icon: Icons.restart_alt,
              text: 'Reinicia inventario, empaques y consecutivo de facturas.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: AppText(text)),
        ],
      ),
    );
  }
}
