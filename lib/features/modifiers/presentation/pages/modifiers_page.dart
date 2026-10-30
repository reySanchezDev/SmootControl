import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/backoffice_new_action.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';
import 'package:smoo_control/features/modifiers/presentation/bloc/modifiers_bloc.dart';
import 'package:smoo_control/features/modifiers/presentation/bloc/modifiers_event.dart';
import 'package:smoo_control/features/modifiers/presentation/bloc/modifiers_state.dart';
import 'package:smoo_control/features/modifiers/presentation/widgets/modifier_dialogs.dart';
import 'package:smoo_control/features/modifiers/presentation/widgets/modifier_group_tile.dart';
import 'package:smoo_control/features/modifiers/presentation/widgets/modifiers_backoffice_table.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Maintenance page for reusable POS modifiers.
class ModifiersPage extends StatelessWidget {
  /// Creates the page.
  const ModifiersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider(
      create: (_) =>
          serviceLocator<ModifiersBloc>()..add(const ModifiersLoadRequested()),
      child: Builder(
        builder: (context) => AppPageScaffold(
          actions: [
            BackofficeNewAction(
              onPressed: () => _openGroupDialog(context),
            ),
          ],
          title: l10n.moduleModifiers,
          body: BlocBuilder<ModifiersBloc, ModifiersState>(
            builder: (context, state) {
              return switch (state) {
                ModifiersInitial() ||
                ModifiersLoading() => const AppLoadingPage(),
                ModifiersFailure(:final failure) => AppEmptyState(
                  icon: Icons.error_outline,
                  message: failure.message,
                  title: l10n.moduleModifiers,
                ),
                ModifiersLoaded(:final catalog) when catalog.groups.isEmpty =>
                  AppEmptyState(
                    icon: Icons.tune_outlined,
                    message: l10n.emptyModifiersMessage,
                    title: l10n.emptyModifiersTitle,
                  ),
                ModifiersLoaded(:final catalog) =>
                  ModifiersBackofficeTable(
                    groups: catalog.groups,
                    optionsFor: catalog.optionsFor,
                    onAddOption: (group) => _openOptionDialog(context, group),
                    onEditGroup: (group) =>
                        _openGroupDialog(context, group: group),
                    onEditOption: (group, option) => _openOptionDialog(
                      context,
                      group,
                      option: option,
                    ),
                    onDeactivateGroup: (group) =>
                        _confirmDeactivateGroup(context, group),
                    compactBuilder: (context, group) => ModifierGroupTile(
                      group: group,
                      onAddOption: () => _openOptionDialog(context, group),
                      onEditGroup: () =>
                          _openGroupDialog(context, group: group),
                      onEditOption: (option) => _openOptionDialog(
                        context,
                        group,
                        option: option,
                      ),
                      onDeactivateGroup: () =>
                          _confirmDeactivateGroup(context, group),
                      onDeactivateOption: (option) {
                        unawaited(_confirmDeactivateOption(context, option));
                      },
                      options: catalog.optionsFor(group.id),
                    ),
                  ),
              };
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openGroupDialog(
    BuildContext context, {
    ModifierGroup? group,
  }) async {
    final result = await showDialog<ModifierGroup>(
      context: context,
      builder: (_) => ModifierGroupDialog(group: group),
    );
    if (result != null && context.mounted) {
      context.read<ModifiersBloc>().add(ModifierGroupSaved(result));
    }
  }

  Future<void> _openOptionDialog(
    BuildContext context,
    ModifierGroup group, {
    ModifierOption? option,
  }) async {
    final result = await showDialog<ModifierOption>(
      context: context,
      builder: (_) => ModifierOptionDialog(group: group, option: option),
    );
    if (result != null && context.mounted) {
      context.read<ModifiersBloc>().add(ModifierOptionSaved(result));
    }
  }

  Future<void> _confirmDeactivateGroup(
    BuildContext context,
    ModifierGroup group,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmationDialog(
      context,
      title: l10n.deactivateModifierGroupTitle,
      message: l10n.deactivateModifierGroupMessage(group.name),
      confirmLabel: l10n.deactivateAction,
      cancelLabel: l10n.cancelAction,
      destructive: true,
    );
    if (confirmed && context.mounted) {
      context.read<ModifiersBloc>().add(
        ModifierGroupSaved(
          ModifierGroup(
            id: group.id,
            name: group.name,
            isRequired: group.isRequired,
            displayOrder: group.displayOrder,
            isActive: false,
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeactivateOption(
    BuildContext context,
    ModifierOption option,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmationDialog(
      context,
      title: l10n.deactivateModifierOptionTitle,
      message: l10n.deactivateModifierOptionMessage(option.name),
      confirmLabel: l10n.deactivateAction,
      cancelLabel: l10n.cancelAction,
      destructive: true,
    );
    if (confirmed && context.mounted) {
      context.read<ModifiersBloc>().add(
        ModifierOptionSaved(
          ModifierOption(
            id: option.id,
            groupId: option.groupId,
            name: option.name,
            priceDeltaInCents: option.priceDeltaInCents,
            displayOrder: option.displayOrder,
            isActive: false,
            isAvailableInPos: false,
          ),
        ),
      );
    }
  }
}
