import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/app_tile_actions.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_new_action.dart';
import 'package:smoo_control/core/design_system/confirm_deactivate_dialog.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/features/users/domain/entities/app_user_profile.dart';
import 'package:smoo_control/features/users/presentation/bloc/users_bloc.dart';
import 'package:smoo_control/features/users/presentation/bloc/users_event.dart';
import 'package:smoo_control/features/users/presentation/bloc/users_state.dart';
import 'package:smoo_control/features/users/presentation/widgets/create_user_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Users management page.
class UsersPage extends StatelessWidget {
  /// Creates the users page.
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider(
      create: (_) =>
          serviceLocator<UsersBloc>()..add(const UsersLoadRequested()),
      child: Builder(
        builder: (context) => AppPageScaffold(
          actions: [
            BackofficeNewAction(
              onPressed: () => _openCreateDialog(context),
            ),
          ],
          title: l10n.moduleUsers,
          body: BlocBuilder<UsersBloc, UsersState>(
            builder: (context, state) {
              return switch (state) {
                UsersInitial() || UsersLoading() => const AppLoadingPage(),
                UsersFailure(:final failure) => AppEmptyState(
                  icon: Icons.error_outline,
                  message: failure.message,
                  title: l10n.moduleUsers,
                ),
                UsersLoaded(:final users) when users.isEmpty => AppEmptyState(
                  icon: Icons.people_outline,
                  message: l10n.emptyUsersMessage,
                  title: l10n.emptyUsersTitle,
                ),
                UsersLoaded() => _UsersList(state: state),
              };
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final state = context.read<UsersBloc>().state;
    if (state is! UsersLoaded) return;
    final result = await showDialog<CreateUserDialogResult>(
      context: context,
      builder: (_) => CreateUserDialog(roles: state.roles),
    );

    if (result != null && context.mounted) {
      context.read<UsersBloc>().add(
        UserSaved(result.user, pin: result.pin),
      );
    }
  }
}

class _UsersList extends StatelessWidget {
  const _UsersList({required this.state});

  final UsersLoaded state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BackofficeCollectionView<AppUserProfile>(
      items: state.users,
      searchLabel: 'Buscar usuario, correo o rol',
      searchTextFor: (user) =>
          '${user.displayName} ${user.email} ${_roleName(user.roleId)}',
      emptyTitle: l10n.emptySearchTitle,
      emptyMessage: l10n.emptySearchMessage,
      compactBuilder: (context, user) => _UserTile(
        roleName: _roleName(user.roleId),
        user: user,
        onDeactivate: () => _deactivateUser(context, user),
        onEdit: () => _openEditDialog(context, user),
      ),
      columns: [
        BackofficeListColumn(
          label: 'Usuario',
          width: 290,
          compare: (a, b) => a.displayName.compareTo(b.displayName),
          cell: (_, user) => Text(user.displayName, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Correo',
          width: 350,
          compare: (a, b) => a.email.compareTo(b.email),
          cell: (_, user) => Text(user.email, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Rol',
          width: 235,
          compare: (a, b) =>
              _roleName(a.roleId).compareTo(_roleName(b.roleId)),
          cell: (_, user) => Text(_roleName(user.roleId)),
        ),
        BackofficeListColumn(
          label: 'Estado',
          width: 125,
          alignment: Alignment.center,
          compare: (a, b) =>
              (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0),
          cell: (_, user) =>
              Text(user.isActive ? l10n.activeStatus : l10n.inactiveStatus),
        ),
        BackofficeListColumn(
          label: 'Acciones',
          width: 255,
          alignment: Alignment.center,
          cell: (_, user) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () => _openEditDialog(context, user),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: Text(l10n.editAction),
              ),
              if (user.isActive)
                TextButton.icon(
                  onPressed: () => _deactivateUser(context, user),
                  icon: const Icon(Icons.toggle_off_outlined, size: 17),
                  label: Text(l10n.deactivateAction),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _roleName(String roleId) {
    for (final role in state.roles) {
      if (role.id == roleId) return role.name;
    }
    return '';
  }

  Future<void> _openEditDialog(
    BuildContext context,
    AppUserProfile user,
  ) async {
    final result = await showDialog<CreateUserDialogResult>(
      context: context,
      builder: (_) => CreateUserDialog(roles: state.roles, user: user),
    );

    if (result != null && context.mounted) {
      context.read<UsersBloc>().add(
        UserSaved(result.user, pin: result.pin),
      );
    }
  }

  Future<void> _deactivateUser(
    BuildContext context,
    AppUserProfile user,
  ) async {
    final confirmed = await confirmDeactivateCatalogItem(
      context,
      name: user.displayName,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    context.read<UsersBloc>().add(UserSaved(user.copyWith(isActive: false)));
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.onDeactivate,
    required this.onEdit,
    required this.roleName,
    required this.user,
  });

  final VoidCallback onDeactivate;
  final VoidCallback onEdit;
  final String roleName;
  final AppUserProfile user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = user.isActive ? l10n.activeStatus : l10n.inactiveStatus;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return ListTile(
          leading: const Icon(Icons.person_outline),
          subtitle: AppText(
            '$roleName · $status',
            variant: AppTextVariant.label,
          ),
          title: AppText(
            user.displayName,
          ),
          trailing: AppTileActions(
            compact: compact,
            actions: [
              if (user.isActive)
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
