import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_stock_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_stock_item.dart';

/// Reads inventory stock directly from Supabase for administrative screens.
///
/// The POS keeps using local stock for offline operation. Admin inventory views
/// use this service so the owner sees the central remote truth.
final class SupabaseInventoryAdminReadService {
  /// Creates the service.
  const SupabaseInventoryAdminReadService({
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required CurrentRemoteSessionService remoteSessionService,
    required http.Client client,
  }) : _config = config,
       _restaurantService = restaurantService,
       _remoteSessionService = remoteSessionService,
       _client = client;

  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final CurrentRemoteSessionService _remoteSessionService;
  final http.Client _client;

  /// Returns product stock from the remote central database.
  Future<AppResult<List<InventoryStockItem>>> getTrackedProductStock() async {
    try {
      final products = await _getRows('products', {
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'tracks_inventory': 'eq.true',
        'is_active': 'eq.true',
        'select': 'id,name',
      });
      final stockRows = await _getRows('inventory_stock', {
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'select': 'product_id,quantity_on_hand,updated_at',
      });
      final stockByProduct = {
        for (final row in stockRows) _text(row['product_id']): row,
      };

      final items = <InventoryStockItem>[];
      for (final product in products) {
        final productId = _text(product['id']);
        final stock = stockByProduct[productId];
        items.add(
          InventoryStockItem(
            productId: productId,
            productName: _text(product['name'], fallback: 'Producto'),
            quantityOnHand: _int(stock?['quantity_on_hand']),
            updatedAt: _date(stock?['updated_at']),
          ),
        );
      }
      items.sort((a, b) => a.productName.compareTo(b.productName));
      return AppSuccess(items);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'remote_inventory_read_failed',
          message:
              'No se pudo leer el inventario remoto. Verifica conexion y '
              'sesion administrativa.',
          cause: error,
        ),
      );
    }
  }

  /// Returns packaging stock from the remote central database.
  Future<AppResult<List<PackagingStockItem>>> getPackagingStock() async {
    try {
      final packagingItems = await _getRows('packaging_items', {
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'tracks_stock': 'eq.true',
        'is_active': 'eq.true',
        'select': 'id,name',
      });
      final stockRows = await _getRows('packaging_stock', {
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'select': 'packaging_item_id,quantity_on_hand,updated_at',
      });
      final stockByPackaging = {
        for (final row in stockRows) _text(row['packaging_item_id']): row,
      };

      final items = <PackagingStockItem>[];
      for (final packaging in packagingItems) {
        final packagingItemId = _text(packaging['id']);
        final stock = stockByPackaging[packagingItemId];
        items.add(
          PackagingStockItem(
            packagingItemId: packagingItemId,
            packagingName: _text(packaging['name'], fallback: 'Empaque'),
            quantityOnHand: _int(stock?['quantity_on_hand']),
            updatedAt: _date(stock?['updated_at']),
          ),
        );
      }
      items.sort((a, b) => a.packagingName.compareTo(b.packagingName));
      return AppSuccess(items);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'remote_packaging_stock_read_failed',
          message:
              'No se pudo leer el stock remoto de empaques. Verifica conexion '
              'y sesion administrativa.',
          cause: error,
        ),
      );
    }
  }

  Future<List<Map<String, Object?>>> _getRows(
    String table,
    Map<String, String> query,
  ) async {
    final token = _remoteSessionService.accessToken;
    if (!_config.isConfigured ||
        !_restaurantService.isConfigured ||
        token == null) {
      throw StateError('Se requiere conexion y sesion remota administrativa.');
    }

    final response = await _client.get(
      _config.restUri(table, query),
      headers: {
        'apikey': _config.publishableKey,
        'authorization': 'Bearer $token',
        'accept': 'application/json',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Supabase rechazo lectura en $table (${response.statusCode}): '
        '${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<Object?, Object?>>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime _date(Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return DateTime.now();
    return DateTime.tryParse(text) ?? DateTime.now();
  }
}
