import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_roles.dart';

/// Resolves catalog actions from authenticated server-side role permissions.
Future<({bool products, bool packaging})> loadCanonicalCatalogAccess(
  SupabaseAdminRepository repository,
) async {
  final session = serviceLocator<CurrentOperatorService>().session;
  if (session == null) return (products: false, packaging: false);
  if (session.roleId == DefaultAccessRoles.adminId) {
    return (products: true, packaging: true);
  }
  final result = await repository.getPermissionCodesForRole(session.roleId);
  return result.when(
    success: (codes) => (
      products: codes.contains('productos.gestionar'),
      packaging: codes.contains('empaques.gestionar'),
    ),
    failure: (_) => (products: false, packaging: false),
  );
}
