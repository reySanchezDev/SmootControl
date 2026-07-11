import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:uuid/uuid.dart';

/// Product purchase row submitted by the administrative inventory screen.
final class AdminInventoryPurchaseItem {
  /// Creates a product purchase row.
  const AdminInventoryPurchaseItem({
    required this.productId,
    required this.quantity,
    required this.unitCostInCents,
  });

  /// Remote product id.
  final String productId;

  /// Purchased units.
  final int quantity;

  /// Unit cost in minor currency units.
  final int unitCostInCents;
}

/// Packaging purchase row submitted by the administrative inventory screen.
final class AdminPackagingPurchaseItem {
  /// Creates a packaging purchase row.
  const AdminPackagingPurchaseItem({
    required this.packagingItemId,
    required this.quantity,
    required this.unitCostInCents,
  });

  /// Remote packaging item id.
  final String packagingItemId;

  /// Purchased units.
  final int quantity;

  /// Unit cost in minor currency units.
  final int unitCostInCents;
}

/// Writes administrative inventory purchases directly to Supabase.
final class SupabaseInventoryAdminWriteService {
  /// Creates the service.
  const SupabaseInventoryAdminWriteService({
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required CurrentRemoteSessionService remoteSessionService,
    required http.Client client,
    Uuid uuid = const Uuid(),
  }) : _config = config,
       _restaurantService = restaurantService,
       _remoteSessionService = remoteSessionService,
       _client = client,
       _uuid = uuid;

  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final CurrentRemoteSessionService _remoteSessionService;
  final http.Client _client;
  final Uuid _uuid;

  /// Registers product purchases as one remote transaction.
  Future<AppResult<void>> registerProductPurchaseBatch(
    List<AdminInventoryPurchaseItem> items,
  ) {
    return _postBatch(
      functionName: 'app_register_inventory_purchase_batch',
      emptyCode: 'inventory_batch_empty',
      emptyMessage: 'Agrega al menos un producto con cantidad.',
      items: [
        for (final item in items)
          {
            'movement_id': _uuid.v4(),
            'product_id': item.productId,
            'quantity': item.quantity,
            'unit_cost': _money(item.unitCostInCents),
          },
      ],
    );
  }

  /// Registers packaging purchases as one remote transaction.
  Future<AppResult<void>> registerPackagingPurchaseBatch(
    List<AdminPackagingPurchaseItem> items,
  ) {
    return _postBatch(
      functionName: 'app_register_packaging_purchase_batch',
      emptyCode: 'packaging_batch_empty',
      emptyMessage: 'Agrega al menos un empaque con cantidad.',
      items: [
        for (final item in items)
          {
            'movement_id': _uuid.v4(),
            'packaging_item_id': item.packagingItemId,
            'quantity': item.quantity,
            'unit_cost': _money(item.unitCostInCents),
          },
      ],
    );
  }

  Future<AppResult<void>> _postBatch({
    required String functionName,
    required String emptyCode,
    required String emptyMessage,
    required List<Map<String, Object?>> items,
  }) async {
    try {
      if (items.isEmpty) {
        return AppFailureResult(
          AppFailure(code: emptyCode, message: emptyMessage),
        );
      }
      final token = _remoteSessionService.accessToken;
      if (!_config.isConfigured ||
          !_restaurantService.isConfigured ||
          token == null) {
        return const AppFailureResult(
          AppFailure(
            code: 'remote_admin_session_required',
            message: 'Se requiere conexion y sesion remota administrativa.',
          ),
        );
      }

      final response = await _client.post(
        _config.rpcUri(functionName),
        headers: {
          'apikey': _config.publishableKey,
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode({
          'p_restaurant_id': _restaurantService.restaurantId,
          'p_items': items,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const AppSuccess<void>(null);
      }
      return AppFailureResult(
        AppFailure(
          code: 'remote_inventory_batch_failed',
          message:
              'Supabase rechazo la compra por lote. Verifica permisos y datos.',
          cause: response.body,
        ),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'remote_inventory_batch_failed',
          message: 'No se pudo registrar la compra por lote.',
          cause: error,
        ),
      );
    }
  }

  num _money(int cents) => cents / 100;
}
