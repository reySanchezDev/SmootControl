import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/system/data/services/pilot_operation_reset_service.dart';

part 'pilot_operation_reset_widgets_part.dart';

/// Administrative utilities for controlled operational cleanup.
class PilotOperationResetPage extends StatefulWidget {
  /// Creates the system utilities page.
  const PilotOperationResetPage({super.key});

  @override
  State<PilotOperationResetPage> createState() =>
      _PilotOperationResetPageState();
}

class _PilotOperationResetPageState extends State<PilotOperationResetPage> {
  String? _busyAction;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Utilidades',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _IntroCard(),
          const SizedBox(height: 14),
          _Section(
            title: 'Ventas y caja',
            children: [
              _CleanupCard(
                busy: _busyAction == PilotCleanupScope.sales.remoteValue,
                confirmation: PilotCleanupScope.sales.confirmationText,
                description:
                    'Elimina ventas POS, detalle, anulaciones, tickets, '
                    'cuentas separadas, movimientos de venta y cola local '
                    'de ventas. Reinicia el consecutivo fiscal en este movil '
                    'y en Supabase.',
                icon: Icons.point_of_sale_outlined,
                onRun: () => _runScope(PilotCleanupScope.sales),
                title: 'Limpiar ventas POS',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Gastos',
            children: [
              _CleanupCard(
                busy: _busyAction == PilotCleanupScope.expenses.remoteValue,
                confirmation: PilotCleanupScope.expenses.confirmationText,
                description:
                    'Elimina solo gastos operativos de prueba. Conserva '
                    'categorias de gastos y adelantos de salario.',
                icon: Icons.receipt_long_outlined,
                onRun: () => _runScope(PilotCleanupScope.expenses),
                title: 'Limpiar gastos',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Personal',
            children: [
              _CleanupCard(
                busy:
                    _busyAction ==
                    PilotCleanupScope.staffConsumptions.remoteValue,
                confirmation:
                    PilotCleanupScope.staffConsumptions.confirmationText,
                description:
                    'Elimina consumos de personal, detalle y movimientos '
                    'asociados. Conserva empleados y puestos. Requiere '
                    'limpiar planilla primero si los consumos ya fueron '
                    'aplicados.',
                icon: Icons.restaurant_menu_outlined,
                onRun: () => _runScope(PilotCleanupScope.staffConsumptions),
                title: 'Limpiar consumos de personal',
              ),
              _CleanupCard(
                busy:
                    _busyAction == PilotCleanupScope.salaryAdvances.remoteValue,
                confirmation: PilotCleanupScope.salaryAdvances.confirmationText,
                description:
                    'Elimina adelantos de salario y sus gastos tecnicos si '
                    'afectaron caja. Conserva empleados, puestos y salarios.',
                icon: Icons.payments_outlined,
                onRun: () => _runScope(PilotCleanupScope.salaryAdvances),
                title: 'Limpiar adelantos',
              ),
              _CleanupCard(
                busy: _busyAction == PilotCleanupScope.payroll.remoteValue,
                confirmation: PilotCleanupScope.payroll.confirmationText,
                description:
                    'Elimina planillas y pagos de prueba. Libera consumos '
                    'de personal aplicados para que puedan limpiarse o '
                    'reprocesarse.',
                icon: Icons.assignment_turned_in_outlined,
                onRun: () => _runScope(PilotCleanupScope.payroll),
                title: 'Limpiar planilla',
              ),
              _CleanupCard(
                busy:
                    _busyAction ==
                    PilotCleanupScope.staffOperations.remoteValue,
                confirmation:
                    PilotCleanupScope.staffOperations.confirmationText,
                description:
                    'Ejecuta una limpieza compuesta: planilla, consumos y '
                    'adelantos. Conserva empleados, puestos y reglas del '
                    'negocio.',
                icon: Icons.groups_2_outlined,
                onRun: () => _runScope(PilotCleanupScope.staffOperations),
                title: 'Limpiar personal operativo',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Reinicio total',
            children: [
              _CleanupCard(
                destructive: true,
                busy: _busyAction == 'full_reset',
                confirmation: PilotOperationResetService.confirmationText,
                description:
                    'Elimina toda la operacion de prueba: ventas, cajas, '
                    'gastos, adelantos, planilla, consumos, movimientos, '
                    'tickets y cola local. Conserva catalogos, usuarios, '
                    'empleados y configuracion base.',
                icon: Icons.delete_sweep_outlined,
                onRun: _runFullReset,
                title: 'Reiniciar produccion',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _runScope(PilotCleanupScope scope) async {
    final confirmation = await _askConfirmation(
      confirmationText: scope.confirmationText,
      title: _scopeTitle(scope),
    );
    if (confirmation == null || !mounted) return;

    setState(() => _busyAction = scope.remoteValue);
    final result = await serviceLocator<PilotOperationResetService>()
        .resetScope(scope: scope, confirmation: confirmation);
    if (!mounted) return;
    setState(() => _busyAction = null);

    await _showResult(
      successTitle: 'Limpieza completada',
      result: result,
    );
  }

  Future<void> _runFullReset() async {
    final confirmation = await _askConfirmation(
      confirmationText: PilotOperationResetService.confirmationText,
      title: 'Reiniciar produccion',
    );
    if (confirmation == null || !mounted) return;

    setState(() => _busyAction = 'full_reset');
    final result = await serviceLocator<PilotOperationResetService>()
        .resetPilotOperation(confirmation: confirmation);
    if (!mounted) return;
    setState(() => _busyAction = null);

    await _showResult(
      successTitle: 'Reinicio completado',
      result: result,
    );
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
                      'Esta accion limpia primero este movil y su cola local; '
                      'despues limpia Supabase. Para continuar escribe:',
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
