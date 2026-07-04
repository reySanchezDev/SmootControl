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

class _ModifierGroupAvailabilityCard extends StatelessWidget {
  const _ModifierGroupAvailabilityCard({
    required this.group,
    required this.onChanged,
    required this.options,
    required this.savingOptionIds,
  });

  final ModifierGroup group;
  final List<ModifierOption> options;
  final Set<String> savingOptionIds;
  final void Function(ModifierOption option, {required bool available})
  onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        color: colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.tune_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppText(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                    variant: AppTextVariant.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          if (options.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: AppText('Sin opciones activas'),
            )
          else
            Padding(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 720;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in options)
                        SizedBox(
                          width: isWide
                              ? (constraints.maxWidth - 8) / 2
                              : constraints.maxWidth,
                          child: _ModifierOptionAvailabilityTile(
                            isSaving: savingOptionIds.contains(option.id),
                            onChanged: (value) => onChanged(
                              option,
                              available: value,
                            ),
                            option: option,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ModifierOptionAvailabilityTile extends StatelessWidget {
  const _ModifierOptionAvailabilityTile({
    required this.isSaving,
    required this.onChanged,
    required this.option,
  });

  final bool isSaving;
  final ValueChanged<bool> onChanged;
  final ModifierOption option;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = option.isAvailableInPos
        ? colorScheme.primary
        : colorScheme.error;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: isSaving ? null : () => onChanged(!option.isAvailableInPos),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                option.isAvailableInPos
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                color: statusColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      option.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      variant: AppTextVariant.label,
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      option.isAvailableInPos ? 'Disponible' : 'No disponible',
                      style: TextStyle(color: statusColor),
                      variant: AppTextVariant.label,
                    ),
                  ],
                ),
              ),
              if (isSaving)
                const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch.adaptive(
                  value: option.isAvailableInPos,
                  onChanged: onChanged,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
