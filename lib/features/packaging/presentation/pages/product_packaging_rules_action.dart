import 'package:flutter/material.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/packaging/presentation/pages/product_packaging_rules_dialog.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_roles.dart';

/// Product-specific entry; never assumes products.gestionar implies
/// empaques.gestionar. The backend independently enforces writes by JWT/RLS.
class ProductPackagingRulesAction extends StatefulWidget {
  /// Visible within the editor of an existing product.
  const ProductPackagingRulesAction({
    required this.product,
    required this.enabled,
    this.permissionLoader,
    super.key,
  });

  /// Persisted product; new products cannot have rules before being saved.
  final Product product;

  /// False when the surrounding product editor has unsaved changes.
  final bool enabled;

  /// Optional permission loader used by isolated widget tests.
  final Future<AppResult<bool>> Function()? permissionLoader;

  @override
  State<ProductPackagingRulesAction> createState() =>
      _ProductPackagingRulesActionState();
}

class _ProductPackagingRulesActionState
    extends State<ProductPackagingRulesAction> {
  late Future<AppResult<bool>> _permission;

  @override
  void initState() {
    super.initState();
    _permission = widget.permissionLoader?.call() ?? _checkPermission();
  }

  Future<AppResult<bool>> _checkPermission() async {
    final session = serviceLocator<CurrentOperatorService>().session;
    if (session == null) return const AppSuccess(false);
    if (session.roleId == DefaultAccessRoles.adminId) {
      return const AppSuccess(true);
    }
    final result = await serviceLocator<SupabaseAdminRepository>()
        .getPermissionCodesForRole(session.roleId);
    return result.when(
      success: (codes) => AppSuccess(codes.contains('empaques.gestionar')),
      failure: AppFailureResult.new,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppResult<bool>>(
      future: _permission,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return snapshot.data!.when(
          failure: (_) => const SizedBox.shrink(),
          success: (allowed) {
            if (!allowed) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Empaque y consumo'),
                  subtitle: Text(
                    widget.enabled
                        ? 'Administrá los empaques utilizados según la modalidad de venta.'
                        : 'Guardá los cambios del producto antes de editar sus reglas.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: widget.enabled,
                  onTap: widget.enabled
                      ? () => showDialog<void>(
                          context: context,
                          builder: (_) => ProductPackagingRulesDialog(
                            product: widget.product,
                          ),
                        )
                      : null,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
