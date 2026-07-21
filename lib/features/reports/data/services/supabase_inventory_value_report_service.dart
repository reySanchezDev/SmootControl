import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/reports/domain/entities/inventory_value_report.dart';

/// Builds the inventory value report directly from Supabase.
final class SupabaseInventoryValueReportService {
  /// Creates the service.
  const SupabaseInventoryValueReportService({
    required http.Client client,
    required SupabaseAppConfig config,
    required CurrentRemoteSessionService remoteSessionService,
    required CurrentRestaurantService restaurantService,
  }) : _client = client,
       _config = config,
       _remoteSessionService = remoteSessionService,
       _restaurantService = restaurantService;

  final http.Client _client;
  final SupabaseAppConfig _config;
  final CurrentRemoteSessionService _remoteSessionService;
  final CurrentRestaurantService _restaurantService;

  /// Loads the current inventory value snapshot.
  Future<AppResult<InventoryValueReport>> load() async {
    if (!_config.isConfigured ||
        !_restaurantService.isConfigured ||
        !_remoteSessionService.hasUsableToken) {
      return const AppFailureResult(
        AppFailure(
          code: 'inventory_value_report_not_configured',
          message: 'Supabase no esta configurado para reportes.',
        ),
      );
    }

    try {
      final products = await _loadProducts();
      final categories = await _loadCategories();
      final stockByProductId = await _loadStockByProductId();
      final rows = <InventoryValueReportRow>[];

      for (final product in products) {
        final stock = stockByProductId[product.id] ?? 0;
        final categoryName = _categoryPath(product.categoryId, categories);
        rows.add(
          InventoryValueReportRow(
            categoryName: categoryName.isEmpty ? 'Sin categoria' : categoryName,
            costInCents: product.baseUnitCostInCents,
            isRawMaterial: product.isRawMaterial,
            priceInCents: product.priceInCents,
            productId: product.id,
            productName: product.name,
            quantityOnHand: stock,
          ),
        );
      }

      rows.sort((a, b) {
        final category = a.categoryName.compareTo(b.categoryName);
        if (category != 0) return category;
        return a.productName.compareTo(b.productName);
      });

      return AppSuccess(
        InventoryValueReport(generatedAt: DateTime.now(), rows: rows),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'inventory_value_report_failed',
          message: 'No se pudo consultar el valor de inventario.',
          cause: error,
        ),
      );
    }
  }

  Future<List<_RemoteInventoryProduct>> _loadProducts() async {
    final rows = await _getRows('products', {
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'tracks_inventory': 'eq.true',
      'is_active': 'eq.true',
      'select':
          'id,name,category_id,cost,price,is_raw_material,'
          'purchase_to_inventory_factor',
      'order': 'name.asc',
    });

    return rows.map((row) {
      return _RemoteInventoryProduct(
        categoryId: _optionalText(row['category_id']) ?? '',
        costInCents: _moneyToCents(row['cost']),
        id: _requiredText(row, 'id'),
        isRawMaterial: _bool(row['is_raw_material']),
        name: _requiredText(row, 'name'),
        priceInCents: _moneyToCents(row['price']),
        purchaseToInventoryFactor: _decimal(
          row['purchase_to_inventory_factor'],
        ),
      );
    }).toList();
  }

  Future<Map<String, _RemoteInventoryCategory>> _loadCategories() async {
    final rows = await _getRows('product_categories', {
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'select': 'id,parent_id,name',
    });

    return {
      for (final row in rows)
        _requiredText(row, 'id'): _RemoteInventoryCategory(
          id: _requiredText(row, 'id'),
          name: _requiredText(row, 'name'),
          parentId: _optionalText(row['parent_id']),
        ),
    };
  }

  Future<Map<String, double>> _loadStockByProductId() async {
    final rows = await _getRows('inventory_stock', {
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'select': 'product_id,quantity_on_hand',
    });

    return {
      for (final row in rows)
        _requiredText(row, 'product_id'): _decimal(row['quantity_on_hand']),
    };
  }

  Future<List<Map<String, Object?>>> _getRows(
    String table,
    Map<String, String> queryParameters,
  ) async {
    final response = await _client.get(
      _config.restUri(table, queryParameters),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        _remoteSessionService.expire();
      }
      throw StateError(
        'Supabase rechazo consulta de $table '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  Map<String, String> _headers() {
    return {
      'apikey': _config.publishableKey,
      'Authorization': 'Bearer ${_remoteSessionService.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  String _categoryPath(
    String categoryId,
    Map<String, _RemoteInventoryCategory> categories,
  ) {
    final names = <String>[];
    final visited = <String>{};
    var currentId = categoryId;
    while (currentId.isNotEmpty && visited.add(currentId)) {
      final category = categories[currentId];
      if (category == null) break;
      names.insert(0, category.name);
      currentId = category.parentId ?? '';
    }
    return names.join(' / ');
  }

  double _decimal(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _moneyToCents(Object? value) {
    if (value == null) return 0;
    if (value is num) return (value * 100).round();
    return ((num.tryParse(value.toString()) ?? 0) * 100).round();
  }

  bool _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString().toLowerCase() == 'true';
  }

  String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _requiredText(Map<String, Object?> row, String key) {
    final value = _optionalText(row[key]);
    if (value == null) throw StateError('Missing required field $key.');
    return value;
  }
}

final class _RemoteInventoryCategory {
  const _RemoteInventoryCategory({
    required this.id,
    required this.name,
    this.parentId,
  });

  final String id;
  final String name;
  final String? parentId;
}

final class _RemoteInventoryProduct {
  const _RemoteInventoryProduct({
    required this.categoryId,
    required this.costInCents,
    required this.id,
    required this.isRawMaterial,
    required this.name,
    required this.priceInCents,
    required this.purchaseToInventoryFactor,
  });

  final String categoryId;
  final int costInCents;
  final String id;
  final bool isRawMaterial;
  final String name;
  final int priceInCents;
  final double purchaseToInventoryFactor;

  int get baseUnitCostInCents {
    if (!isRawMaterial || purchaseToInventoryFactor <= 0) return costInCents;
    return (costInCents / purchaseToInventoryFactor).round();
  }
}
