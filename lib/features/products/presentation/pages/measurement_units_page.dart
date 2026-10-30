import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/backoffice_new_action.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';

part 'measurement_units_dialog_part.dart';

/// Remote admin page for measurement unit maintenance.
class MeasurementUnitsPage extends StatefulWidget {
  /// Creates the page.
  const MeasurementUnitsPage({super.key});

  @override
  State<MeasurementUnitsPage> createState() => _MeasurementUnitsPageState();
}

class _MeasurementUnitsPageState extends State<MeasurementUnitsPage> {
  late Future<List<MeasurementUnit>> _future;
  final SupabaseAdminRepository _repository =
      serviceLocator<SupabaseAdminRepository>();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Unidades',
      actions: [
        BackofficeNewAction(
          onPressed: _openNewDialog,
        ),
      ],
      body: FutureBuilder<List<MeasurementUnit>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingPage();
          }
          final units = snapshot.data ?? const <MeasurementUnit>[];
          if (units.isEmpty) {
            return const AppEmptyState(
              icon: Icons.straighten_outlined,
              title: 'Sin unidades',
              message: 'Las unidades de medida apareceran aqui.',
            );
          }
          return BackofficeCollectionView<MeasurementUnit>(
            items: units,
            searchLabel: 'Buscar unidad, código o grupo',
            searchTextFor: (unit) =>
                '${unit.name} ${unit.code} ${_groupName(unit.unitGroup)}',
            emptyTitle: 'Sin resultados',
            emptyMessage: 'No hay unidades que coincidan con la búsqueda.',
            compactBuilder: (_, unit) => Card(
              child: _UnitTile(
                onEdit: () => _openDialog(unit: unit),
                onToggle: () => _toggle(unit),
                unit: unit,
              ),
            ),
            columns: [
              BackofficeListColumn(
                label: 'Unidad',
                width: 310,
                compare: (a, b) => a.name.compareTo(b.name),
                cell: (_, unit) => Text(unit.name, softWrap: true),
              ),
              BackofficeListColumn(
                label: 'Código',
                width: 140,
                compare: (a, b) => a.code.compareTo(b.code),
                cell: (_, unit) => Text(unit.code),
              ),
              BackofficeListColumn(
                label: 'Grupo',
                width: 170,
                compare: (a, b) => a.unitGroup.compareTo(b.unitGroup),
                cell: (_, unit) => Text(_groupName(unit.unitGroup)),
              ),
              BackofficeListColumn(
                label: 'Factor',
                width: 130,
                alignment: Alignment.centerRight,
                compare: (a, b) => a.baseFactor.compareTo(b.baseFactor),
                cell: (_, unit) => Text('${unit.baseFactor}'),
              ),
              BackofficeListColumn(
                label: 'Estado',
                width: 140,
                alignment: Alignment.center,
                compare: (a, b) =>
                    (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0),
                cell: (_, unit) => Text(unit.isActive ? 'Activo' : 'Inactivo'),
              ),
              BackofficeListColumn(
                label: 'Acciones',
                width: 270,
                alignment: Alignment.center,
                cell: (_, unit) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => _openDialog(unit: unit),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar'),
                    ),
                    TextButton.icon(
                      onPressed: () => _toggle(unit),
                      icon: Icon(
                        unit.isActive
                            ? Icons.toggle_off_outlined
                            : Icons.toggle_on_outlined,
                        size: 18,
                      ),
                      label: Text(unit.isActive ? 'Inactivar' : 'Activar'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<MeasurementUnit>> _load() async {
    final result = await _repository.getMeasurementUnits();
    return switch (result) {
      AppSuccess(:final value) => value,
      AppFailureResult(:final error) => throw StateError(error.message),
    };
  }

  Future<void> _openDialog({MeasurementUnit? unit}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _MeasurementUnitDialog(
        onSave: _save,
        unit: unit,
      ),
    );
    if ((saved ?? false) && mounted) {
      setState(() => _future = _load());
    }
  }

  Future<void> _openNewDialog() => _openDialog();

  Future<String?> _save(_MeasurementUnitDraft draft) async {
    final factor = double.tryParse(draft.factor.trim());
    if (draft.code.trim().isEmpty ||
        draft.name.trim().isEmpty ||
        factor == null ||
        factor <= 0) {
      return 'Completa codigo, nombre y factor mayor que cero.';
    }
    final unit = draft.unit;
    final result = unit == null
        ? await _repository.createMeasurementUnit(
            code: draft.code,
            name: draft.name,
            unitGroup: draft.group,
            baseFactor: factor,
          )
        : await _repository.updateMeasurementUnit(
            MeasurementUnit(
              id: unit.id,
              code: draft.code,
              name: draft.name,
              unitGroup: draft.group,
              baseFactor: factor,
              isActive: unit.isActive,
            ),
          );
    return switch (result) {
      AppSuccess() => null,
      AppFailureResult(:final error) => error.message,
    };
  }

  Future<void> _toggle(MeasurementUnit unit) async {
    if (unit.isActive) {
      final confirmed = await showAppConfirmationDialog(
        context,
        title: 'Inactivar unidad',
        message: '¿Deseás inactivar «${unit.name}»?',
        confirmLabel: 'Inactivar',
        cancelLabel: 'Cancelar',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    final result = await _repository.setMeasurementUnitActive(
      id: unit.id,
      isActive: !unit.isActive,
    );
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        setState(() => _future = _load());
      case AppFailureResult(:final error):
        await showAppMessageDialog(
          context: context,
          message: error.message,
          title: 'No se pudo actualizar la unidad',
        );
    }
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({
    required this.onEdit,
    required this.onToggle,
    required this.unit,
  });

  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final MeasurementUnit unit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.straighten_outlined,
        color: unit.isActive ? null : Theme.of(context).disabledColor,
      ),
      title: AppText('${unit.name} (${unit.code})'),
      subtitle: AppText(
        '${_groupName(unit.unitGroup)} - Factor ${unit.baseFactor}',
        variant: AppTextVariant.label,
      ),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            icon: Icon(unit.isActive ? Icons.visibility_off : Icons.visibility),
            onPressed: onToggle,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

String _groupName(String value) {
  return switch (value) {
    'mass' => 'Masa',
    'volume' => 'Volumen',
    _ => 'Conteo',
  };
}
