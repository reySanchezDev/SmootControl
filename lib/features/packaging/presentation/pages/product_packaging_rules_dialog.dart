import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/product_packaging_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:uuid/uuid.dart';

part 'product_packaging_rules_form_part.dart';

/// Product-focused rule editor. Never changes the product or its identifiers.
class ProductPackagingRulesDialog extends StatefulWidget {
  /// Creates the rule editor for a persisted product.
  const ProductPackagingRulesDialog({
    required this.product,
    this.rulesLoader,
    this.salesTypesLoader,
    this.packagingItemsLoader,
    this.saveRule,
    super.key,
  });

  /// Existing product selected from the product catalog.
  final Product product;

  /// Optional rules loader used by isolated widget tests.
  final Future<AppResult<List<ProductPackagingRule>>> Function()? rulesLoader;

  /// Optional service modalities loader used by isolated widget tests.
  final Future<AppResult<List<SalesType>>> Function()? salesTypesLoader;

  /// Optional packaging items loader used by isolated widget tests.
  final Future<AppResult<List<PackagingItem>>> Function()? packagingItemsLoader;

  /// Optional save callback used by isolated widget tests.
  final Future<AppResult<ProductPackagingRule>> Function(
    ProductPackagingRule rule,
  )?
  saveRule;

  @override
  State<ProductPackagingRulesDialog> createState() =>
      _ProductPackagingRulesDialogState();
}

class _ProductPackagingRulesDialogState
    extends State<ProductPackagingRulesDialog> {
  SupabaseAdminRepository get _repository =>
      serviceLocator<SupabaseAdminRepository>();
  late Future<AppResult<_RuleCatalog>> _catalog = _load();

  Future<AppResult<_RuleCatalog>> _load() async {
    final rules = await (widget.rulesLoader?.call() ?? _repository.getRules());
    final salesTypes =
        await (widget.salesTypesLoader?.call() ?? _repository.getSalesTypes());
    final packaging =
        await (widget.packagingItemsLoader?.call() ??
            _repository.getPackagingItems());
    if (rules case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    if (salesTypes case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    if (packaging case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    return AppSuccess(
      _RuleCatalog(
        rules: (rules as AppSuccess<List<ProductPackagingRule>>).value
            .where((rule) => rule.productId == widget.product.id)
            .toList(),
        salesTypes: (salesTypes as AppSuccess<List<SalesType>>).value,
        packagingItems: (packaging as AppSuccess<List<PackagingItem>>).value,
      ),
    );
  }

  Future<void> _edit(
    _RuleCatalog catalog, [
    ProductPackagingRule? original,
  ]) async {
    final changed = await showDialog<ProductPackagingRule>(
      context: context,
      builder: (_) => _ProductRuleForm(
        catalog: catalog,
        product: widget.product,
        original: original,
      ),
    );
    if (changed == null || !mounted) return;
    final result =
        await (widget.saveRule?.call(changed) ?? _repository.saveRule(changed));
    if (!mounted) return;
    await result.when(
      success: (_) async {
        final catalogFuture = _load();
        setState(() {
          _catalog = catalogFuture;
        });
      },
      failure: (failure) async {
        await showAppMessageDialog(
          context: context,
          title: 'No se pudo guardar la regla',
          message: failure.message,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Empaque y consumo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(widget.product.name),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<AppResult<_RuleCatalog>>(
                  future: _catalog,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return snapshot.data!.when(
                      failure: (failure) =>
                          Center(child: Text(failure.message)),
                      success: (catalog) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed:
                                  catalog.salesTypes.isEmpty ||
                                      catalog.packagingItems.isEmpty
                                  ? null
                                  : () => _edit(catalog),
                              icon: const Icon(Icons.add),
                              label: const Text('Nueva regla'),
                            ),
                          ),
                          Expanded(
                            child: catalog.rules.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Este producto no tiene reglas de '
                                      'empaque.',
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: catalog.rules.length,
                                    itemBuilder: (context, index) {
                                      final rule = catalog.rules[index];
                                      final salesName =
                                          catalog.salesTypes
                                              .where(
                                                (x) => x.id == rule.salesTypeId,
                                              )
                                              .map((x) => x.name)
                                              .firstOrNull ??
                                          'Modalidad no disponible';
                                      final packagingName =
                                          catalog.packagingItems
                                              .where(
                                                (x) =>
                                                    x.id ==
                                                    rule.packagingItemId,
                                              )
                                              .map((x) => x.name)
                                              .firstOrNull ??
                                          'Empaque no disponible';
                                      return ListTile(
                                        title: Text(
                                          '$salesName · $packagingName',
                                        ),
                                        subtitle: Text(
                                          '${rule.quantityPerUnit} por '
                                          'unidad · '
                                          '${rule.isActive ? 'Activa' : 'Inactiva'}',
                                        ),
                                        trailing: IconButton(
                                          tooltip: 'Editar regla',
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _edit(catalog, rule),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleCatalog {
  const _RuleCatalog({
    required this.rules,
    required this.salesTypes,
    required this.packagingItems,
  });
  final List<ProductPackagingRule> rules;
  final List<SalesType> salesTypes;
  final List<PackagingItem> packagingItems;
}
