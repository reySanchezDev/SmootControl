import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/reports/domain/entities/negative_inventory_report.dart';

/// Reads raw materials with negative stock directly from Supabase.
final class SupabaseNegativeInventoryReportService {
  /// Creates the report service.
  const SupabaseNegativeInventoryReportService({
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

  /// Loads the current negative raw-material inventory.
  Future<AppResult<NegativeInventoryReport>> load() async {
    if (!_config.isConfigured ||
        !_restaurantService.isConfigured ||
        !_remoteSessionService.hasUsableToken) {
      return const AppFailureResult(
        AppFailure(
          code: 'negative_inventory_not_configured',
          message: 'Supabase no esta configurado para reportes.',
        ),
      );
    }

    try {
      final stock = await _loadNegativeStock();
      if (stock.isEmpty) {
        return AppSuccess(
          NegativeInventoryReport(generatedAt: DateTime.now(), rows: const []),
        );
      }
      final ids = stock.keys.toList();
      final products = await _loadProducts(ids);
      final categories = await _loadCategories();
      final movements = await _loadLastRecipeMovements(ids);
      final rows = <NegativeInventoryRow>[];

      for (final id in ids) {
        final product = products[id];
        if (product == null) continue;
        final movement = movements[id];
        rows.add(
          NegativeInventoryRow(
            categoryName: _categoryPath(product.categoryId, categories),
            costInCents: product.costInCents,
            lastMovementAt: movement?.createdAt,
            lastReferenceId: movement?.referenceId,
            productId: id,
            productName: product.name,
            quantityOnHand: stock[id] ?? 0,
          ),
        );
      }

      rows.sort((a, b) => a.quantityOnHand.compareTo(b.quantityOnHand));
      return AppSuccess(
        NegativeInventoryReport(generatedAt: DateTime.now(), rows: rows),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'negative_inventory_failed',
          message: 'No se pudo consultar inventario negativo.',
          cause: error,
        ),
      );
    }
  }

  Future<Map<String, int>> _loadNegativeStock() async {
    final rows = await _getRows('inventory_stock', {
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'quantity_on_hand': 'lt.0',
      'select': 'product_id,quantity_on_hand',
    });
    return {
      for (final row in rows)
        _requiredText(row, 'product_id'): _int(row['quantity_on_hand']),
    };
  }

  Future<Map<String, _ProductRow>> _loadProducts(List<String> ids) async {
    final rows = await _getRows('products', {
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'id': _inFilter(ids),
      'product_kind': 'eq.raw_material',
      'tracks_inventory': 'eq.true',
      'select': 'id,name,category_id,cost',
    });
    return {
      for (final row in rows)
        _requiredText(row, 'id'): _ProductRow(
          categoryId: _optionalText(row['category_id']) ?? '',
          costInCents: _moneyToCents(row['cost']),
          name: _requiredText(row, 'name'),
        ),
    };
  }

  Future<Map<String, _CategoryRow>> _loadCategories() async {
    final rows = await _getRows('product_categories', {
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'select': 'id,parent_id,name',
    });
    return {
      for (final row in rows)
        _requiredText(row, 'id'): _CategoryRow(
          name: _requiredText(row, 'name'),
          parentId: _optionalText(row['parent_id']),
        ),
    };
  }

  Future<Map<String, _MovementRow>> _loadLastRecipeMovements(
    List<String> ids,
  ) async {
    final rows = await _getRows('inventory_movements', {
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'product_id': _inFilter(ids),
      'movement_type': 'eq.recipe_consumption',
      'quantity_delta': 'lt.0',
      'select': 'product_id,reference_id,created_at',
      'order': 'created_at.desc',
    });
    final result = <String, _MovementRow>{};
    for (final row in rows) {
      final productId = _requiredText(row, 'product_id');
      result.putIfAbsent(
        productId,
        () => _MovementRow(
          createdAt: _dateTime(row['created_at']),
          referenceId: _optionalText(row['reference_id']),
        ),
      );
    }
    return result;
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
      throw StateError('Supabase rechazo $table: ${response.body}');
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
    Map<String, _CategoryRow> categories,
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
    return names.isEmpty ? 'Sin categoria' : names.join(' / ');
  }

  DateTime _dateTime(Object? value) {
    return DateTime.parse(value.toString()).toLocal();
  }

  String _inFilter(List<String> ids) => 'in.(${ids.join(',')})';

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _moneyToCents(Object? value) {
    if (value == null) return 0;
    if (value is num) return (value * 100).round();
    return ((num.tryParse(value.toString()) ?? 0) * 100).round();
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

final class _CategoryRow {
  const _CategoryRow({required this.name, this.parentId});

  final String name;
  final String? parentId;
}

final class _MovementRow {
  const _MovementRow({required this.createdAt, required this.referenceId});

  final DateTime createdAt;
  final String? referenceId;
}

final class _ProductRow {
  const _ProductRow({
    required this.categoryId,
    required this.costInCents,
    required this.name,
  });

  final String categoryId;
  final int costInCents;
  final String name;
}
