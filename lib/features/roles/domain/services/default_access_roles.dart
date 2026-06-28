import 'package:smoo_control/features/roles/domain/entities/access_role.dart';

/// Default role catalog for V1.
abstract final class DefaultAccessRoles {
  /// Owner/admin role id.
  static const adminId = 'role-admin';

  /// Cashier role id.
  static const cashierId = 'role-cashier';

  /// Waiter role id.
  static const waiterId = 'role-waiter';

  /// Roles available on first app start.
  static const values = [
    AccessRole(
      id: adminId,
      name: 'Administrador',
      description: 'Acceso completo al sistema',
      isSystem: true,
      isActive: true,
    ),
    AccessRole(
      id: cashierId,
      name: 'Cajero',
      description: 'Ventas, caja y cuentas separadas',
      isSystem: true,
      isActive: true,
    ),
    AccessRole(
      id: waiterId,
      name: 'Mesero',
      description: 'Registro de consumo y separacion de cuentas',
      isSystem: true,
      isActive: true,
    ),
  ];
}
