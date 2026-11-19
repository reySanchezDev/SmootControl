import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/backoffice_action_feedback.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/products/presentation/widgets/canonical_item_labels.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'canonical_item_editor_fields_part.dart';

/// Creates and edits all three canonical types through one article form.
class CanonicalItemEditor extends StatefulWidget {
  /// Creates the form with data already authorized for the current tenant.
  const CanonicalItemEditor({
    required this.units,
    required this.classifications,
    required this.allowedClasses,
    required this.initialClass,
    required this.onSave,
    required this.onBack,
    this.categories = const [],
    this.saving = false,
    this.item,
    super.key,
  });

  /// Existing article or null to create.
  final CanonicalItem? item;

  /// Called after local validation; persistence is owned by the parent.
  final ValueChanged<CanonicalItem> onSave;

  /// Returns to the same catalog tab, never pushes a route.
  final VoidCallback onBack;

  /// Whether persistence is currently in progress.
  final bool saving;

  /// Measurement units available to the restaurant.
  final List<MeasurementUnit> units;

  /// Independent functional classifications.
  final List<CanonicalClassification> classifications;

  /// Business classes the authenticated role may create in this form.
  final Set<CanonicalItemClass> allowedClasses;

  /// Initial role for a new item, respecting the route and role permissions.
  final CanonicalItemClass initialClass;

  /// Active product categories available to the tenant.
  final List<ProductCategory> categories;

  @override
  State<CanonicalItemEditor> createState() => CanonicalItemEditorState();
}

/// State API used by workspace close guards to protect unsaved edits.
class CanonicalItemEditorState extends State<CanonicalItemEditor> {
  bool _closeConfirmed = false;

  void _update(VoidCallback action) {
    if (mounted) setState(action);
  }

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cost = TextEditingController(text: '0');
  final _price = TextEditingController(text: '0');
  late CanonicalItemType _type;
  late CanonicalItemClass _itemClass;
  late CanonicalItemClass _lastNonServiceClass;
  late bool _canSell;
  late bool _canPurchase;
  late bool _visibleInPos;
  late bool _usesRecipe;
  late bool _sendToKitchen;
  late bool _isActive;
  late Set<String> _classifications;
  String? _categoryId;
  String? _baseUnit;
  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name.text = item?.name ?? '';
    _cost.text = item?.cost.toString() ?? '0';
    _price.text = item?.price.toString() ?? '0';
    _type = item?.type ?? CanonicalItemType.inventory;
    _itemClass = item?.itemClass ?? widget.initialClass;
    _lastNonServiceClass = _itemClass == CanonicalItemClass.service
        ? CanonicalItemClass.saleProduct
        : _itemClass;
    _canSell = item?.canSell ?? false;
    _canPurchase = item?.canPurchase ?? true;
    _visibleInPos = item?.visibleInPos ?? false;
    _usesRecipe = item?.usesRecipe ?? false;
    _sendToKitchen = item?.sendToKitchen ?? false;
    _isActive = item?.isActive ?? true;
    _classifications = {...?item?.classificationIds};
    _categoryId = item?.categoryId;
    _baseUnit = item?.baseUnitId;
  }

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _price.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Obligatorio';
    return null;
  }

  String? _nonnegative(String? value) {
    final number = double.tryParse((value ?? '').replaceAll(',', '.'));
    if (number == null || !number.isFinite || number < 0) {
      return 'Ingresá un importe válido';
    }
    return null;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_baseUnit == null) {
      BackofficeActionFeedback.show(
        context,
        outcome: BackofficeActionOutcome.warning,
        message: 'Seleccioná una unidad base.',
      );
      return;
    }
    if (_visibleInPos && !_canSell) return;
    if (_usesRecipe && _type == CanonicalItemType.service) return;
    widget.onSave(
      CanonicalItem(
        id: widget.item?.id,
        commercialCode: widget.item?.commercialCode,
        categoryId: _categoryId,
        code: widget.item?.code ?? '',
        name: _name.text.trim(),
        type: _type,
        itemClass: _itemClass,
        baseUnitId: _baseUnit!,
        cost: double.parse(_cost.text.replaceAll(',', '.')),
        price: double.parse(_price.text.replaceAll(',', '.')),
        canSell: _canSell,
        canPurchase: _canPurchase,
        visibleInPos: _visibleInPos,
        usesRecipe: _usesRecipe,
        sendToKitchen: _sendToKitchen,
        isActive: _isActive,
        classificationIds: _classifications.toList(),
      ),
    );
  }

  bool get _hasChanges {
    final previous = widget.item;
    return _name.text != (previous?.name ?? '') ||
        _cost.text != (previous?.cost.toString() ?? '0') ||
        _price.text != (previous?.price.toString() ?? '0') ||
        _baseUnit != previous?.baseUnitId ||
        _categoryId != previous?.categoryId ||
        _type != (previous?.type ?? CanonicalItemType.inventory) ||
        _itemClass != (previous?.itemClass ?? CanonicalItemClass.saleProduct) ||
        _canSell != (previous?.canSell ?? false) ||
        _canPurchase != (previous?.canPurchase ?? true) ||
        _visibleInPos != (previous?.visibleInPos ?? false) ||
        _usesRecipe != (previous?.usesRecipe ?? false) ||
        _sendToKitchen != (previous?.sendToKitchen ?? false) ||
        _isActive != (previous?.isActive ?? true) ||
        !_classifications.containsAll(
          previous?.classificationIds ?? const [],
        ) ||
        _classifications.length != (previous?.classificationIds.length ?? 0);
  }

  /// Confirms whether the workspace may dispose this editor tab.
  Future<bool> confirmClose() async {
    _closeConfirmed = false;
    await _back();
    return _closeConfirmed;
  }

  Future<void> _back() async {
    _closeConfirmed = false;
    if (widget.saving) return;
    if (_hasChanges) {
      final discard = await showAppConfirmationDialog(
        context,
        title: 'Cambios sin guardar',
        message: '¿Descartar los cambios y regresar a Productos?',
        confirmLabel: 'Descartar',
        cancelLabel: 'Seguir editando',
        destructive: true,
      );
      if (!discard || !mounted) return;
    }
    _closeConfirmed = true;
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    final units = widget.units.where((unit) => unit.isActive).toList();
    if (_baseUnit != null && !units.any((unit) => unit.id == _baseUnit)) {
      units.addAll(widget.units.where((unit) => unit.id == _baseUnit));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: widget.saving ? null : _back,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Regresar'),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  widget.item == null ? 'Nuevo artículo' : 'Editar artículo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: widget.saving ? null : _save,
                icon: widget.saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: _fields(context, units, widget.categories),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
