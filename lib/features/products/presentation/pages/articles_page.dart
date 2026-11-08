import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_selection_toolbar.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_catalog.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_item.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/presentation/widgets/create_product_dialog.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_roles.dart';
import 'package:uuid/uuid.dart';

part 'articles_page_view_part.dart';

/// One Backoffice catalog over existing products and packaging items.
/// No schema merge: source table and stable identifier are preserved per row.
class ArticlesPage extends StatefulWidget {
  /// Creates the unified articles catalog.
  const ArticlesPage({this.initialType = 'all', super.key});

  /// Optional filter for bookmarked legacy packaging catalog links.
  final String initialType;

  @override
  State<ArticlesPage> createState() => _ArticlesPageState();
}

class _Article {
  const _Article.product(this.product) : packaging = null;
  const _Article.packaging(this.packaging) : product = null;

  final Product? product;
  final PackagingItem? packaging;

  String get id => product == null
      ? 'packaging:${packaging!.id}'
      : 'product:${product!.id}';
  String get name => product?.name ?? packaging!.name;
  String get type => packaging != null
      ? 'Empaque'
      : product!.isRawMaterial ? 'Materia prima' : 'Producto de venta';
  bool get active => product?.isActive ?? packaging!.isActive;
  bool get stock => product?.tracksInventory ?? packaging!.tracksStock;
  int get cost => product?.costInCents ?? packaging!.costInCents;
}

class _ArticlesSnapshot {
  const _ArticlesSnapshot({
    required this.items,
    required this.categories,
    required this.canProducts,
    required this.canPackaging,
  });
  final List<_Article> items;
  final List<ProductCategory> categories;
  final bool canProducts;
  final bool canPackaging;
}

class _ArticlesPageState extends State<ArticlesPage> {
  SupabaseAdminRepository get _repo =>
      serviceLocator<SupabaseAdminRepository>();
  late Future<AppResult<_ArticlesSnapshot>> _future;
  late String _type;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _future = _load();
  }

  Future<AppResult<_ArticlesSnapshot>> _load() async {
    final session = serviceLocator<CurrentOperatorService>().session;
    if (session == null) return const AppSuccess(
      _ArticlesSnapshot(
        items: [], categories: [], canProducts: false, canPackaging: false,
      ),
    );
    final isAdmin = session.roleId == DefaultAccessRoles.adminId;
    final rights = isAdmin
        ? const AppSuccess(<String>['productos.gestionar','empaques.gestionar'])
        : await _repo.getPermissionCodesForRole(session.roleId);
    if (rights case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    final codes = (rights as AppSuccess<List<String>>).value.toSet();
    final canProducts = codes.contains('productos.gestionar');
    final canPackaging = codes.contains('empaques.gestionar');
    final items = <_Article>[];
    var categories = <ProductCategory>[];
    if (canProducts) {
      final products = await _repo.getProducts();
      if (products case AppFailureResult(:final error)) {
        return AppFailureResult(error);
      }
      items.addAll((products as AppSuccess<List<Product>>)
          .value.map(_Article.product));
      final result = await _repo.getCategories();
      if (result case AppFailureResult(:final error)) {
        return AppFailureResult(error);
      }
      categories = (result as AppSuccess<List<ProductCategory>>).value;
    }
    if (canPackaging) {
      final result = await _repo.getPackagingItems();
      if (result case AppFailureResult(:final error)) {
        return AppFailureResult(error);
      }
      items.addAll((result as AppSuccess<List<PackagingItem>>)
          .value.map(_Article.packaging));
    }
    return AppSuccess(_ArticlesSnapshot(
      items: items,
      categories: categories,
      canProducts: canProducts,
      canPackaging: canPackaging,
    ));
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _message(String title, String message) async {
    if (!mounted) return;
    await showAppMessageDialog(
      context: context, title: title, message: message,
    );
  }

  Future<void> _saved<T>(AppResult<T> result) async {
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        _reload();
      case AppFailureResult(:final error):
        await _message('No se pudo guardar', error.message);
    }
  }

  Future<void> _editProduct(Product? item, _ArticlesSnapshot snapshot) async {
    final categories = snapshot.categories;
    final groups = await _repo.getCatalog();
    final units = await _repo.getMeasurementUnits();
    if (!mounted) return;
    if (groups case AppFailureResult(:final error)) {
      await _message('No se pudo abrir el formulario', error.message);
      return;
    }
    if (units case AppFailureResult(:final error)) {
      await _message('No se pudo abrir el formulario', error.message);
      return;
    }
    final groupList = (groups as AppSuccess<ModifierCatalog>).value.groups;
    final unitList = (units as AppSuccess<List<MeasurementUnit>>).value;
    if (!mounted) return;
    final saved = await showDialog<Product>(
      context: context,
      builder: (_) => CreateProductDialog(
        categories: categories, modifierGroups: groupList,
        units: unitList, product: item,
      ),
    );
    if (saved == null || !mounted) return;
    await _saved(await _repo.saveProduct(saved));
  }

  Future<void> _editPackaging(PackagingItem? item) async {
    final saved = await showDialog<PackagingItem>(
      context: context,
      builder: (_) => _ArticlePackagingDialog(item: item),
    );
    if (saved == null || !mounted) return;
    await _saved(await _repo.savePackagingItem(saved));
  }

  Future<void> _deactivate(_Article article) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Inactivar artículo',
      message: '¿Inactivar ${article.name}? Se conservarán su historial y sus movimientos.',
      confirmLabel: 'Inactivar',
      cancelLabel: 'Cancelar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final product = article.product;
    if (product != null) {
      await _saved(await _repo.saveProduct(Product(
        id: product.id, categoryId: product.categoryId,
        name: product.name, priceInCents: product.priceInCents,
        costInCents: product.costInCents, isActive: false,
        isAvailableInPos: false, isRawMaterial: product.isRawMaterial,
        usesRecipe: product.usesRecipe,
        tracksInventory: product.tracksInventory,
        purchaseUnitId: product.purchaseUnitId,
        inventoryUnitId: product.inventoryUnitId,
        recipeDefaultUnitId: product.recipeDefaultUnitId,
        inventoryDisplayUnitId: product.inventoryDisplayUnitId,
        purchaseToInventoryFactor: product.purchaseToInventoryFactor,
        optionGroups: product.optionGroups,
        modifierGroupIds: product.modifierGroupIds,
      )));
    } else {
      final pack = article.packaging!;
      await _saved(await _repo.savePackagingItem(PackagingItem(
        id: pack.id, name: pack.name, costInCents: pack.costInCents,
        tracksStock: pack.tracksStock, isActive: false,
      )));
    }
  }

  @override
  Widget build(BuildContext context) => AppPageScaffold(
    title: 'Productos',
    body: FutureBuilder<AppResult<_ArticlesSnapshot>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return snapshot.data!.when(
          failure: (failure) => Center(child: Text(failure.message)),
          success: (value) => _articlesContent(value),
        );
      },
    ),
  );
}
