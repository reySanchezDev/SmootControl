import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/recipes/data/services/supabase_product_recipes_service.dart';
import 'package:smoo_control/features/recipes/domain/entities/product_recipe.dart';
import 'package:smoo_control/features/recipes/presentation/widgets/product_recipe_row_card.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Dialog for configuring the active recipe of one product.
class ProductRecipeDialog extends StatefulWidget {
  /// Creates a recipe dialog.
  const ProductRecipeDialog({
    required this.components,
    required this.product,
    required this.service,
    required this.units,
    this.recipe,
    super.key,
  });

  /// Product that owns the recipe.
  final Product product;

  /// Existing active recipe.
  final ProductRecipe? recipe;

  /// Products allowed as recipe components.
  final List<Product> components;

  /// Units available for recipe quantities.
  final List<MeasurementUnit> units;

  /// Remote recipe service.
  final SupabaseProductRecipesService service;

  @override
  State<ProductRecipeDialog> createState() => _ProductRecipeDialogState();
}

class _ProductRecipeDialogState extends State<ProductRecipeDialog> {
  late final List<ProductRecipeRowDraft> _rows;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rows = [
      for (final line in widget.recipe?.lines ?? const <ProductRecipeLine>[])
        ProductRecipeRowDraft.fromLine(line),
    ];
    if (_rows.isEmpty) _rows.add(ProductRecipeRowDraft());
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compact = MediaQuery.sizeOf(context).width < 560;
    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 40,
        vertical: compact ? 16 : 24,
      ),
      title: AppText(
        '${l10n.productRecipeTitle}: ${widget.product.name}',
        variant: AppTextVariant.titleMedium,
        maxLines: 2,
      ),
      content: SizedBox(
        width: compact ? double.maxFinite : 720,
        height: compact ? 520 : 560,
        child: widget.components.isEmpty || widget.units.isEmpty
            ? AppEmptyState(
                icon: Icons.restaurant_menu_outlined,
                title: l10n.productRecipeUnavailableTitle,
                message: l10n.productRecipeUnavailableMessage,
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      itemCount: _rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => ProductRecipeRowCard(
                        components: widget.components,
                        onRemove: _rows.length == 1
                            ? null
                            : () => _removeRow(index),
                        row: _rows[index],
                        units: widget.units,
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    AppText(_error!, maxLines: 3),
                  ],
                ],
              ),
      ),
      actions: [
        AppButton(
          label: l10n.createAction,
          onPressed:
              _saving || widget.components.isEmpty || widget.units.isEmpty
              ? null
              : _addRow,
          primary: false,
        ),
        AppButton(
          label: l10n.cancelAction,
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          primary: false,
        ),
        AppButton(
          icon: Icons.save_outlined,
          label: _saving ? l10n.savingAction : l10n.saveAction,
          onPressed:
              _saving || widget.components.isEmpty || widget.units.isEmpty
              ? null
              : _save,
        ),
      ],
    );
  }

  void _addRow() {
    setState(() => _rows.add(ProductRecipeRowDraft()));
  }

  void _removeRow(int index) {
    _rows.removeAt(index).dispose();
    setState(() {});
  }

  Future<void> _save() async {
    final lines = <ProductRecipeLine>[];
    for (var index = 0; index < _rows.length; index++) {
      final line = _rows[index].toLine(index);
      if (line == null) {
        setState(() => _error = AppLocalizations.of(context).numericFieldError);
        return;
      }
      lines.add(line);
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.service.saveRecipe(
      productId: widget.product.id,
      lines: lines,
    );
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        Navigator.of(context).pop(true);
      case AppFailureResult(:final error):
        setState(() {
          _saving = false;
          _error = error.message;
        });
    }
  }
}
