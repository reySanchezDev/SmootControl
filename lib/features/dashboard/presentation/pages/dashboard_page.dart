import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/navigation/app_routes.dart';
import 'package:smoo_control/core/navigation/route_access.dart';
import 'package:smoo_control/core/responsive/responsive_breakpoints.dart';
import 'package:smoo_control/core/responsive/responsive_builder.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_roles.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'dashboard_content_part.dart';
part 'dashboard_widgets_part.dart';

/// Initial responsive dashboard while the V1 modules are scaffolded.
class DashboardPage extends StatelessWidget {
  /// Creates the dashboard page.
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<AppResult<_DashboardAccess>>(
      future: _loadAccess(),
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result == null) return const AppLoadingPage();

        return result.when(
          success: (access) => _DashboardContent(access: access),
          failure: (failure) => AppEmptyState(
            icon: Icons.lock_outline,
            message: failure.message,
            title: l10n.accessDeniedTitle,
          ),
        );
      },
    );
  }

  Future<AppResult<_DashboardAccess>> _loadAccess() async {
    final session = serviceLocator<CurrentOperatorService>().session;
    if (session == null) {
      return const AppSuccess(_DashboardAccess());
    }
    if (session.roleId == DefaultAccessRoles.adminId) {
      return const AppSuccess(_DashboardAccess(isAdmin: true));
    }

    final result = await serviceLocator<SupabaseAdminRepository>()
        .getPermissionCodesForRole(session.roleId);

    return result.when(
      success: (codes) => AppSuccess(
        _DashboardAccess(permissionCodes: codes.toSet()),
      ),
      failure: AppFailureResult.new,
    );
  }
}
