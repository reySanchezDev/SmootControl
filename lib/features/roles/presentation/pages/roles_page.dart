import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_searchable_list_section.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/app_tile_actions.dart';
import 'package:smoo_control/core/design_system/confirm_deactivate_dialog.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';
import 'package:smoo_control/features/roles/presentation/bloc/roles_bloc.dart';
import 'package:smoo_control/features/roles/presentation/bloc/roles_event.dart';
import 'package:smoo_control/features/roles/presentation/bloc/roles_state.dart';
import 'package:smoo_control/features/roles/presentation/widgets/create_role_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Roles and permissions management page.
class RolesPage extends StatelessWidget {
  /// Creates the roles page.
  const RolesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider(
      create: (_) =>
          serviceLocator<RolesBloc>()..add(const RolesLoadRequested()),
      child: Builder(
        builder: (context) => AppPageScaffold(
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openCreateDialog(context),
              tooltip: l10n.createAction,
            ),
          ],
          title: l10n.moduleRoles,
          body: BlocBuilder<RolesBloc, RolesState>(
            builder: (context, state) {
              return switch (state) {
                RolesInitial() || RolesLoading() => const AppLoadingPage(),
                RolesFailure(:final failure) => AppEmptyState(
                  icon: Icons.error_outline,
                  message: failure.message,
                  title: l10n.moduleRoles,
                ),
                RolesLoaded(:final roles) when roles.isEmpty => AppEmptyState(
                  icon: Icons.admin_panel_settings_outlined,
                  message: l10n.emptyRolesMessage,
                  title: l10n.emptyRolesTitle,
                ),
                RolesLoaded() => _RolesList(state: state),
              };
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final state = context.read<RolesBloc>().state;
    if (state is! RolesLoaded) return;
    final result = await showDialog<RoleDialogResult>(
      context: context,
      builder: (_) => CreateRoleDialog(
        permissions: state.permissions,
        selectedPermissionCodes: const [],
      ),
    );

    if (result != null && context.mounted) {
      context.read<RolesBloc>().add(
        RoleSaved(
          role: result.role,
          permissionCodes: result.permissionCodes,
        ),
      );
    }
  }
}

class _RolesList extends StatelessWidget {
  const _RolesList({required this.state});

  final RolesLoaded state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppSearchableListSection<AccessRole>(
      emptyMessage: l10n.emptySearchMessage,
      emptyTitle: l10n.emptySearchTitle,
      items: state.roles,
      searchLabel: l10n.searchField,
      searchTextForItem: (role) => [
        role.name,
        role.description ?? '',
        if (role.isActive) l10n.activeStatus else l10n.inactiveStatus,
        '${state.permissionCodesByRole[role.id]?.length ?? 0}',
      ].join(' '),
      itemBuilder: (context, role) => _RoleTile(
        role: role,
        permissionCount: state.permissionCodesByRole[role.id]?.length ?? 0,
        onDeactivate: () => _deactivateRole(context, role),
        onEdit: () => _openEditDialog(context, role),
      ),
    );
  }

  Future<void> _openEditDialog(
    BuildContext context,
    AccessRole role,
  ) async {
    final result = await showDialog<RoleDialogResult>(
      context: context,
      builder: (_) => CreateRoleDialog(
        permissions: state.permissions,
        role: role,
        selectedPermissionCodes:
            state.permissionCodesByRole[role.id] ?? const [],
      ),
    );

    if (result != null && context.mounted) {
      context.read<RolesBloc>().add(
        RoleSaved(
          role: result.role,
          permissionCodes: result.permissionCodes,
        ),
      );
    }
  }

  Future<void> _deactivateRole(
    BuildContext context,
    AccessRole role,
  ) async {
    final confirmed = await confirmDeactivateCatalogItem(
      context,
      name: role.name,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    context.read<RolesBloc>().add(
      RoleSaved(
        role: AccessRole(
          id: role.id,
          name: role.name,
          description: role.description,
          isSystem: role.isSystem,
          isActive: false,
        ),
        permissionCodes: state.permissionCodesByRole[role.id] ?? const [],
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.onDeactivate,
    required this.onEdit,
    required this.permissionCount,
    required this.role,
  });

  final VoidCallback onDeactivate;
  final VoidCallback onEdit;
  final int permissionCount;
  final AccessRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = role.isActive ? l10n.activeStatus : l10n.inactiveStatus;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return ListTile(
          leading: const Icon(Icons.admin_panel_settings_outlined),
          subtitle: AppText(
            '$status · $permissionCount ${l10n.permissionsSection}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            variant: AppTextVariant.label,
          ),
          title: AppText(
            role.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: AppTileActions(
            compact: compact,
            actions: [
              if (role.isActive && !role.isSystem)
                AppTileAction(
                  color: Theme.of(context).colorScheme.error,
                  icon: Icons.delete_outline,
                  label: l10n.deactivateAction,
                  onPressed: onDeactivate,
                ),
              AppTileAction(
                icon: Icons.edit_outlined,
                label: l10n.editAction,
                onPressed: onEdit,
              ),
            ],
          ),
        );
      },
    );
  }
}
