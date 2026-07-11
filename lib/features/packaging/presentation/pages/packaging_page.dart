import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
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
part 'packaging_tabs_part.dart';

/// Manages sales types, packaging items and product packaging rules.
class PackagingPage extends StatefulWidget {
  /// Creates the page.
  const PackagingPage({super.key});

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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const AppText(
            'Empaques',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            variant: AppTextVariant.titleMedium,
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tipos de venta'),
              Tab(text: 'Empaques'),
              Tab(text: 'Reglas'),
            ],
          ),
        ),
        body: SafeArea(
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
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
        setState(_reload);
      case AppFailureResult(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
    }
  }
}
