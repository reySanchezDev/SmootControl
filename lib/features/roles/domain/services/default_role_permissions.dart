import 'package:smoo_control/features/roles/domain/services/default_access_permissions.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_roles.dart';

/// Default permission assignments for V1 roles.
abstract final class DefaultRolePermissions {
  /// Permission codes by default role id.
  static final values = <String, List<String>>{
    DefaultAccessRoles.adminId: [
      for (final permission in DefaultAccessPermissions.values) permission.code,
    ],
    DefaultAccessRoles.cashierId: const [
      'ventas.registrar',
      'caja.aperturar',
      'caja.cerrar',
      'pdf.generar',
      'cuentas.separar',
      'ventas.anular',
      'personal.consumos.registrar',
      'personal.adelantos.gestionar',
    ],
    DefaultAccessRoles.waiterId: const [
      'ventas.registrar',
      'cuentas.separar',
      'personal.consumos.registrar',
    ],
  };
}
