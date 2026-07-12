import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_catalog.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';
import 'package:smoo_control/features/modifiers/domain/repositories/i_modifiers_repository.dart';

part 'pos_modifier_availability_widgets.dart';

/// Touch-first POS screen to toggle daily modifier availability.
class PosModifierAvailabilityPage extends StatefulWidget {
  /// Creates the modifier availability page.
  const PosModifierAvailabilityPage({super.key});

  @override
  State<PosModifierAvailabilityPage> createState() =>
      _PosModifierAvailabilityPageState();
}

class _PosModifierAvailabilityPageState
    extends State<PosModifierAvailabilityPage> {
  late Future<AppResult<ModifierCatalog>> _future;
  ModifierCatalog? _catalog;
  final _savingOptionIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = serviceLocator<IModifiersRepository>().getCatalog();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Modificadores Disponibles',
      body: FutureBuilder<AppResult<ModifierCatalog>>(
        future: _future,
        builder: (context, snapshot) {
          final result = snapshot.data;
          if (result == null) return const AppLoadingPage();

          return result.when(
            success: (catalog) {
              _catalog ??= catalog;
              return _buildCatalog(context, _catalog!);
            },
            failure: (failure) => AppEmptyState(
              icon: Icons.error_outline,
              message: failure.message,
              title: 'No se pudieron cargar los modificadores',
            ),
          );
        },
      ),
    );
  }

  Widget _buildCatalog(BuildContext context, ModifierCatalog catalog) {
    final groups = catalog.groups.where((group) => group.isActive).toList()
      ..sort((first, second) {
        final order = first.displayOrder.compareTo(second.displayOrder);
        if (order != 0) return order;
        return first.name.compareTo(second.name);
      });

    if (groups.isEmpty) {
      return const AppEmptyState(
        icon: Icons.tune_outlined,
        message: 'Crea grupos y opciones en Modificadores POS.',
        title: 'Sin modificadores disponibles',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final group = groups[index];
        return _ModifierGroupAvailabilityCard(
          group: group,
          options: catalog
              .optionsFor(group.id)
              .where((option) => option.isActive)
              .toList(),
          savingOptionIds: _savingOptionIds,
          onChanged: _toggleOption,
        );
      },
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
    );
  }

  Future<void> _toggleOption(
    ModifierOption option, {
    required bool available,
  }) async {
    setState(() => _savingOptionIds.add(option.id));

    final updated = ModifierOption(
      id: option.id,
      groupId: option.groupId,
      name: option.name,
      priceDeltaInCents: option.priceDeltaInCents,
      displayOrder: option.displayOrder,
      isActive: option.isActive,
      isAvailableInPos: available,
    );
    final result = await serviceLocator<IModifiersRepository>()
        .saveOptionAvailability(updated);

    if (!mounted) return;

    switch (result) {
      case AppSuccess(:final value):
        setState(() {
          _savingOptionIds.remove(option.id);
          final current = _catalog;
          if (current == null) return;
          _catalog = ModifierCatalog(
            groups: current.groups,
            options: [
              for (final entry in current.options)
                if (entry.id == value.id) value else entry,
            ],
          );
        });
      case AppFailureResult(:final error):
        setState(() => _savingOptionIds.remove(option.id));
        await showAppMessageDialog(context: context, message: error.message);
    }
  }
}
