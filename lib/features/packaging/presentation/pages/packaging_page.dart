import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_selection_toolbar.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/product_packaging_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:uuid/uuid.dart';

part 'packaging_dialogs_part.dart';
part 'packaging_models_part.dart';
part 'packaging_responsive_dialog_part.dart';
part 'packaging_tab_shell_part.dart';
part 'packaging_tabs_part.dart';

/// Scopes packaging administration without changing its persisted entities.
enum PackagingPageView {
  /// Presents the legacy combined catalog.
  all,

  /// Presents service modalities.
  salesTypes,

  /// Presents packaging items.
  items,

  /// Presents product packaging rules.
  rules,
}

/// Manages sales types, packaging items and product packaging rules.
class PackagingPage extends StatefulWidget {
  /// Creates the page.
  const PackagingPage({this.view = PackagingPageView.all, super.key});

  /// Which catalog is presented; legacy route retains the combined view.
  final PackagingPageView view;

  @override
  State<PackagingPage> createState() => _PackagingPageState();
}

class _PackagingPageState extends State<PackagingPage> {
  late Future<AppResult<_PackagingSnapshot>> _future;

  SupabaseAdminRepository get _repository =>
      serviceLocator<SupabaseAdminRepository>();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _loadSnapshot();
  }

  Future<AppResult<_PackagingSnapshot>> _loadSnapshot() async {
    // Keep independent destinations usable if an unrelated catalog is down.
    if (widget.view == PackagingPageView.salesTypes) {
      final result = await _repository.getSalesTypes();
      return switch (result) {
        AppSuccess(:final value) => AppSuccess(
          _PackagingSnapshot(
            salesTypes: value,
            packagingItems: const [],
            rules: const [],
            products: const [],
          ),
        ),
        AppFailureResult(:final error) => AppFailureResult(error),
      };
    }
    if (widget.view == PackagingPageView.items) {
      final result = await _repository.getPackagingItems();
      return switch (result) {
        AppSuccess(:final value) => AppSuccess(
          _PackagingSnapshot(
            salesTypes: const [],
            packagingItems: value,
            rules: const [],
            products: const [],
          ),
        ),
        AppFailureResult(:final error) => AppFailureResult(error),
      };
    }
    final salesTypes = await _repository.getSalesTypes();
    final packagingItems = await _repository.getPackagingItems();
    final rules = await _repository.getRules();
    final products = await serviceLocator<SupabaseAdminRepository>()
        .getProducts();

    if (salesTypes case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    if (packagingItems case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    if (rules case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    if (products case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }

    return AppSuccess(
      _PackagingSnapshot(
        salesTypes: (salesTypes as AppSuccess<List<SalesType>>).value,
        packagingItems:
            (packagingItems as AppSuccess<List<PackagingItem>>).value,
        rules: (rules as AppSuccess<List<ProductPackagingRule>>).value,
        products: (products as AppSuccess<List<Product>>).value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.view != PackagingPageView.all) {
      final title = switch (widget.view) {
        PackagingPageView.salesTypes => 'Modalidades de servicio',
        PackagingPageView.items => 'Empaques',
        PackagingPageView.rules => 'Reglas de empaque',
        PackagingPageView.all => 'Empaques',
      };
      return AppPageScaffold(
        title: title,
        body: FutureBuilder<AppResult<_PackagingSnapshot>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const AppLoadingPage();
            return switch (snapshot.data!) {
              AppFailureResult(:final error) => AppEmptyState(
                icon: Icons.error_outline,
                title: title,
                message: error.message,
              ),
              AppSuccess(:final value) => _scopedContent(value),
            };
          },
        ),
      );
    }
    return DefaultTabController(
      length: 3,
      child: AppPageScaffold(
        title: 'Empaques',
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Tipos de venta'),
                Tab(text: 'Empaques'),
                Tab(text: 'Reglas'),
              ],
            ),
            Expanded(
              child: FutureBuilder<AppResult<_PackagingSnapshot>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const AppLoadingPage();
                  return switch (snapshot.data!) {
                    AppFailureResult(:final error) => AppEmptyState(
                      icon: Icons.error_outline,
                      title: 'Empaques',
                      message: error.message,
                    ),
                    AppSuccess(:final value) => TabBarView(
                      children: [
                        _SalesTypesTab(
                          salesTypes: value.salesTypes,
                          onSave: _saveSalesType,
                        ),
                        _PackagingItemsTab(
                          items: value.packagingItems,
                          onSave: _savePackagingItem,
                        ),
                        _RulesTab(
                          packagingItems: value.packagingItems,
                          products: value.products,
                          rules: value.rules,
                          salesTypes: value.salesTypes,
                          onSave: _saveRule,
                        ),
                      ],
                    ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scopedContent(_PackagingSnapshot value) {
    return switch (widget.view) {
      PackagingPageView.salesTypes => _SalesTypesTab(
        salesTypes: value.salesTypes,
        onSave: _saveSalesType,
      ),
      PackagingPageView.items => _PackagingItemsTab(
        items: value.packagingItems,
        onSave: _savePackagingItem,
      ),
      PackagingPageView.rules => _RulesTab(
        packagingItems: value.packagingItems,
        products: value.products,
        rules: value.rules,
        salesTypes: value.salesTypes,
        onSave: _saveRule,
      ),
      PackagingPageView.all => const SizedBox.shrink(),
    };
  }

  Future<void> _saveSalesType(SalesType? salesType) async {
    final saved = await showDialog<SalesType>(
      context: context,
      builder: (_) => _SalesTypeDialog(salesType: salesType),
    );
    if (saved == null || !mounted) return;
    await _save(
      _repository.saveSalesType(saved),
      successMessage: 'Tipo de venta guardado.',
    );
  }

  Future<void> _savePackagingItem(PackagingItem? item) async {
    final saved = await showDialog<PackagingItem>(
      context: context,
      builder: (_) => _PackagingItemDialog(item: item),
    );
    if (saved == null || !mounted) return;
    await _save(
      _repository.savePackagingItem(saved),
      successMessage: 'Empaque guardado.',
    );
  }

  Future<void> _saveRule(ProductPackagingRule? rule) async {
    final snapshot = await _future;
    if (!mounted || snapshot is! AppSuccess<_PackagingSnapshot>) return;
    final saved = await showDialog<ProductPackagingRule>(
      context: context,
      builder: (_) => _PackagingRuleDialog(
        packagingItems: snapshot.value.packagingItems,
        products: snapshot.value.products,
        rule: rule,
        salesTypes: snapshot.value.salesTypes,
      ),
    );
    if (saved == null || !mounted) return;
    await _save(
      _repository.saveRule(saved),
      successMessage: 'Regla de empaque guardada.',
    );
  }

  Future<void> _save<T>(
    Future<AppResult<T>> future, {
    required String successMessage,
  }) async {
    final result = await future;
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        setState(_reload);
        await showAppMessageDialog(
          context: context,
          title: 'Registro guardado',
          message: successMessage,
        );
      case AppFailureResult(:final error):
        await showAppMessageDialog(
          context: context,
          title: 'No se pudo guardar',
          message: error.message,
        );
    }
  }
}
