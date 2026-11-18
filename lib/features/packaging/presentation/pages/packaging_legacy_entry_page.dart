import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/navigation/app_routes.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_roles.dart';

/// Compatibility entry for old /packaging bookmarks.
///
/// Never mounts the legacy combined editors. Every destination is independently
/// guarded by its route and by the database permissions.
class PackagingLegacyEntryPage extends StatefulWidget {
  /// Creates the transitional catalog chooser.
  const PackagingLegacyEntryPage({this.permissionsLoader, super.key});

  /// Optional loader used by isolated widget tests.
  ///
  /// Production callers keep the default loader, which reads the authenticated
  /// operator permissions from the remote repository.
  final Future<AppResult<Set<String>>> Function()? permissionsLoader;

  @override
  State<PackagingLegacyEntryPage> createState() =>
      _PackagingLegacyEntryPageState();
}

class _PackagingLegacyEntryPageState extends State<PackagingLegacyEntryPage> {
  late final Future<AppResult<Set<String>>> _permissions;

  @override
  void initState() {
    super.initState();
    _permissions = widget.permissionsLoader?.call() ?? _loadPermissions();
  }

  Future<AppResult<Set<String>>> _loadPermissions() async {
    final session = serviceLocator<CurrentOperatorService>().session;
    if (session == null) {
      return const AppSuccess(<String>{});
    }
    if (session.roleId == DefaultAccessRoles.adminId) {
      return const AppSuccess(<String>{
        'tipos_venta.gestionar',
        'empaques.gestionar',
      });
    }
    final result = await serviceLocator<SupabaseAdminRepository>()
        .getPermissionCodesForRole(session.roleId);
    return result.when(
      success: (codes) => AppSuccess(codes.toSet()),
      failure: AppFailureResult.new,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Administración de empaques',
      body: FutureBuilder<AppResult<Set<String>>>(
        future: _permissions,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return snapshot.data!.when(
            failure: (failure) => Center(child: Text(failure.message)),
            success: (permissions) {
              final canManageTypes = permissions.contains(
                'tipos_venta.gestionar',
              );
              final canManagePackaging = permissions.contains(
                'empaques.gestionar',
              );
              if (!canManageTypes && !canManagePackaging) {
                return const Center(child: Text('Acceso no autorizado'));
              }
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Este módulo ahora se administra desde destinos separados.',
                  ),
                  const SizedBox(height: 20),
                  if (canManageTypes)
                    _destination(
                      context,
                      icon: Icons.room_service_outlined,
                      title: 'Modalidades de servicio',
                      subtitle: 'Configurá las modalidades de venta.',
                      route: AppRoutes.salesTypes,
                    ),
                  if (canManagePackaging) ...[
                    _destination(
                      context,
                      icon: Icons.takeout_dining_outlined,
                      title: 'Empaques',
                      subtitle: 'Administrá el catálogo de empaques.',
                      route: AppRoutes.packagingItems,
                    ),
                    _destination(
                      context,
                      icon: Icons.rule_outlined,
                      title: 'Reglas de consumo',
                      subtitle: 'Asociá empaques con productos y modalidades.',
                      route: AppRoutes.packagingRules,
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _destination(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).pushNamed(route),
      ),
    );
  }
}
