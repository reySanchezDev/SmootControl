import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/app_tile_actions.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_selection_toolbar.dart';
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
                RolesLoaded() => _RolesList(
                  state: state,
                  onCreate: () => _openCreateDialog(context),
                ),
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
  const _RolesList({required this.state, required this.onCreate});

  final RolesLoaded state;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BackofficeCollectionView<AccessRole>(
      items: state.roles,
      onCreate: onCreate,
      rowKey: (role) => role.id,
      rowLabel: (role) => role.name,
      selectionActions: [
        BackofficeSelectionAction(
          label: l10n.editAction,
          icon: Icons.edit_outlined,
          onPressed: (role) => _openEditDialog(context, role),
        ),
        BackofficeSelectionAction(
          label: l10n.deactivateAction,
          icon: Icons.toggle_off_outlined,
          enabledWhen: (role) => role.isActive && !role.isSystem,
          onPressed: (role) => _deactivateRole(context, role),
        ),
      ],
      searchLabel: 'Buscar rol o permiso',
      searchTextFor: (role) =>
          '${role.name} ${role.description ?? ''} '
          '${role.isActive ? l10n.activeStatus : l10n.inactiveStatus}',
      emptyTitle: l10n.emptySearchTitle,
      emptyMessage: l10n.emptySearchMessage,
      compactBuilder: (context, role) => _RoleTile(
        role: role,
        permissionCount: state.permissionCodesByRole[role.id]?.length ?? 0,
        onDeactivate: () => _deactivateRole(context, role),
        onEdit: () => _openEditDialog(context, role),
      ),
      columns: [
        BackofficeListColumn(
          label: 'Rol',
          width: 265,
          compare: (a, b) => a.name.compareTo(b.name),
          cell: (_, role) => Text(role.name, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Descripción',
          width: 350,
          compare: (a, b) =>
              (a.description ?? '').compareTo(b.description ?? ''),
          cell: (_, role) => Text(role.description ?? '—'),
        ),
        BackofficeListColumn(
          label: 'Permisos',
          width: 135,
          alignment: Alignment.centerRight,
          compare: (a, b) =>
              (state.permissionCodesByRole[a.id]?.length ?? 0).compareTo(
                state.permissionCodesByRole[b.id]?.length ?? 0,
              ),
          cell: (_, role) => Text(
            '${state.permissionCodesByRole[role.id]?.length ?? 0}',
          ),
        ),
        BackofficeListColumn(
          label: 'Estado',
          width: 145,
          alignment: Alignment.center,
          compare: (a, b) =>
              (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0),
          cell: (_, role) =>
              Text(role.isActive ? l10n.activeStatus : l10n.inactiveStatus),
        ),
      ],
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
            variant: AppTextVariant.label,
          ),
          title: AppText(
            role.name,
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
