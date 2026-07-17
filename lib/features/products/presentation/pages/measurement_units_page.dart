import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
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
        IconButton(
          icon: const Icon(Icons.add),
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
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: units.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, index) => _UnitTile(
              onEdit: () => _openDialog(unit: units[index]),
              onToggle: () => _toggle(units[index]),
              unit: units[index],
            ),
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
    final result = await _repository.setMeasurementUnitActive(
      id: unit.id,
      isActive: !unit.isActive,
    );
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        setState(() => _future = _load());
      case AppFailureResult(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
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
      title: AppText('${unit.name} (${unit.code})', maxLines: 1),
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
