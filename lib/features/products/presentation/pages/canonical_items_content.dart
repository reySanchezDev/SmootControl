import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/backoffice_action_feedback.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_selection_toolbar.dart';
import 'package:smoo_control/core/design_system/navigation/backoffice_workspace_scope.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/packaging/domain/entities/canonical_consumption_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/packaging/presentation/pages/canonical_packaging_rules_dialog.dart';
import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/products/presentation/widgets/canonical_catalog_access.dart';
import 'package:smoo_control/features/products/presentation/widgets/canonical_item_columns.dart';
import 'package:smoo_control/features/products/presentation/widgets/canonical_item_editor.dart';
import 'package:smoo_control/features/products/presentation/widgets/canonical_item_labels.dart';
import 'package:smoo_control/features/recipes/domain/entities/canonical_recipe.dart';
import 'package:smoo_control/features/recipes/presentation/pages/canonical_recipe_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'canonical_items_content_actions_part.dart';
part 'canonical_items_content_catalog_part.dart';

/// Authenticated item catalog backed only by the canonical item master.
class CanonicalItemsContent extends StatefulWidget {
  /// Creates the canonical Products catalog content.
  const CanonicalItemsContent({this.initialClassFilter, super.key});

  /// Optional canonical class filter for a bookmarked catalog entry.
  final CanonicalItemClass? initialClassFilter;

  @override
  State<CanonicalItemsContent> createState() => _CanonicalItemsContentState();
}

class _CanonicalItemsContentState extends State<CanonicalItemsContent> {
  SupabaseAdminRepository get _repository =>
      serviceLocator<SupabaseAdminRepository>();
  late Future<AppResult<List<CanonicalItem>>> _items = _repository
      .getCanonicalItems();
  late final Future<({bool products, bool packaging})> _access =
      loadCanonicalCatalogAccess(_repository);
  late Future<List<ProductCategory>> _categories = _loadCategories();
  ({
    CanonicalItem? item,
    List<MeasurementUnit> units,
    List<ProductCategory> categories,
    List<CanonicalClassification> classifications,
    Set<CanonicalItemClass> allowedClasses,
    CanonicalItemClass initialClass,
  })?
  _editor;
  CanonicalItemType? _filter;
  CanonicalItemClass? _classFilter;
  bool _busy = false;
  GlobalKey<CanonicalItemEditorState>? _editorKey;

  @override
  void initState() {
    super.initState();
    _classFilter = widget.initialClassFilter;
  }

  void _setBusy(bool value) {
    if (mounted) setState(() => _busy = value);
  }

  void _setTypeFilter(CanonicalItemType? type) =>
      setState(() => _filter = type);

  void _refresh() {
    setState(() {
      _items = _repository.getCanonicalItems();
      _categories = _loadCategories();
    });
  }

  void _leaveEditor() {
    BackofficeWorkspaceScope.registerCloseGuard(context, null);
    _editorKey = null;
    setState(() => _editor = null);
  }

  Future<void> _edit(
    CanonicalItem? current,
    ({bool products, bool packaging}) access,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final unitsResult = await _repository.getMeasurementUnits();
      final classificationsResult = await _repository
          .getCanonicalClassifications();
      final categoriesResult = await _repository.getCategories();
      if (!mounted) return;
      if (unitsResult case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      if (classificationsResult case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      if (categoriesResult case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      _editorKey = GlobalKey<CanonicalItemEditorState>();
      _registerEditorCloseGuard();
      setState(
        () => _editor = (
          item: current,
          units: (unitsResult as AppSuccess<List<MeasurementUnit>>).value,
          categories: (categoriesResult as AppSuccess<List<ProductCategory>>)
              .value
              .where((category) => category.isActive)
              .toList(),
          classifications:
              (classificationsResult
                      as AppSuccess<List<CanonicalClassification>>)
                  .value,
          allowedClasses: {
            if (access.products) ...[
              CanonicalItemClass.saleProduct,
              CanonicalItemClass.rawMaterial,
            ],
            if (access.packaging) CanonicalItemClass.packaging,
          },
          initialClass:
              current?.itemClass ??
              (_classFilter == CanonicalItemClass.packaging && access.packaging
                  ? CanonicalItemClass.packaging
                  : access.products
                  ? CanonicalItemClass.saleProduct
                  : CanonicalItemClass.packaging),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveEditor(CanonicalItem item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await _repository.saveCanonicalItem(item);
      if (!mounted) return;
      switch (result) {
        case AppSuccess():
          _leaveEditor();
          _refresh();
          BackofficeActionFeedback.show(
            context,
            outcome: BackofficeActionOutcome.success,
            message: 'Artículo guardado correctamente.',
          );
        case AppFailureResult(:final error):
          _error(error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: _editor == null ? 0 : 1,
    children: [
      FutureBuilder<AppResult<List<CanonicalItem>>>(
        future: _items,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return snapshot.data!.when(
            failure: (failure) => Center(child: Text(failure.message)),
            success: (items) =>
                FutureBuilder<({bool products, bool packaging})>(
                  future: _access,
                  builder: (context, permission) => !permission.hasData
                      ? const Center(child: CircularProgressIndicator())
                      : FutureBuilder<List<ProductCategory>>(
                          future: _categories,
                          builder: (context, categories) => categories.hasData
                              ? _catalog(
                                  items,
                                  permission.data!,
                                  categories.data!,
                                )
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                        ),
                ),
          );
        },
      ),
      if (_editor != null)
        CanonicalItemEditor(
          key: _editorKey,
          item: _editor!.item,
          units: _editor!.units,
          classifications: _editor!.classifications,
          allowedClasses: _editor!.allowedClasses,
          initialClass: _editor!.initialClass,
          categories: _editor!.categories,
          saving: _busy,
          onBack: _leaveEditor,
          onSave: _saveEditor,
        ),
    ],
  );
}
