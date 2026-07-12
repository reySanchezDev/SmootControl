import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_void.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';
import 'package:uuid/uuid.dart';

part 'supabase_sales_admin_repository_support.dart';

/// Administrative sales repository backed directly by Supabase.
///
/// POS keeps using the local offline repository. This repository is for
/// backoffice screens, where Supabase is the source of truth.
final class SupabaseSalesAdminRepository implements ISalesRepository {
  /// Creates a Supabase-backed sales repository.
  const SupabaseSalesAdminRepository({
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

  @override
  Future<AppResult<List<Sale>>> getSales({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rows = await _getRows('sales', {
        'select':
            'id,invoice_number,table_id,table_account_id,'
            'cash_register_session_id,payment_method_id,payment_reference,'
            'sales_type_id,sales_type_name,status,sync_status,total_amount,'
            'sold_at,created_at',
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'and': _dateRangeFilter('sold_at', from, to),
        'order': 'sold_at.desc',
      });

      return AppSuccess(rows.map(_saleFromRow).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'remote_sales_read_failed',
          message: 'No se pudieron consultar las ventas en Supabase.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<Sale>>> getSalesByCashRegisterSession(
    String sessionId,
  ) async {
    try {
      final rows = await _getRows('sales', {
        'select':
            'id,invoice_number,table_id,table_account_id,'
            'cash_register_session_id,payment_method_id,payment_reference,'
            'sales_type_id,sales_type_name,status,sync_status,total_amount,'
            'sold_at,created_at',
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'cash_register_session_id': 'eq.$sessionId',
        'order': 'sold_at.desc',
      });

      return AppSuccess(rows.map(_saleFromRow).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'remote_sales_by_cash_read_failed',
          message: 'No se pudieron consultar las ventas de caja en Supabase.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<SaleItem>>> getSaleItems(String saleId) async {
    try {
      final rows = await _getRows('sale_items', {
        'select':
            'id,sale_id,table_account_id,product_id,product_code,'
            'product_name,category_name,selected_options_label,quantity,'
            'unit_price,unit_cost,created_at',
        'sale_id': 'eq.$saleId',
        'order': 'created_at.asc',
      });

      return AppSuccess(rows.map(_saleItemFromRow).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'remote_sale_items_read_failed',
          message: 'No se pudo consultar el detalle de la venta en Supabase.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<SaleVoid>>> getSaleVoids({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rows = await _getRows('sale_voids', {
        'select': 'id,sale_id,reason,voided_by_user_id,voided_at',
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'and': _dateRangeFilter('voided_at', from, to),
        'order': 'voided_at.desc',
      });

      return AppSuccess(rows.map(_saleVoidFromRow).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'remote_sale_voids_read_failed',
          message: 'No se pudieron consultar anulaciones en Supabase.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<Sale>> saveSale({
    required Sale sale,
    required List<SaleItem> items,
  }) async {
    return const AppFailureResult(
      AppFailure(
        code: 'remote_sales_save_not_supported',
        message: 'Las ventas se registran desde el POS.',
      ),
    );
  }

  @override
  Future<AppResult<Sale>> voidSale({
    required String saleId,
    required String reason,
    required String voidedBy,
  }) async {
    try {
      final saleRows = await _getRows('sales', {
        'select':
            'id,invoice_number,table_id,table_account_id,'
            'cash_register_session_id,payment_method_id,payment_reference,'
            'sales_type_id,sales_type_name,status,sync_status,total_amount,'
            'sold_at,created_at',
        'id': 'eq.$saleId',
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'limit': '1',
      });
      if (saleRows.isEmpty) {
        throw StateError('Venta no encontrada en Supabase.');
      }

      await _patchRows(
        'sales',
        {'status': 'voided', 'updated_at': DateTime.now().toIso8601String()},
        {'id': 'eq.$saleId'},
      );
      await _insertRow('sale_voids', {
        'id': _uuid.v4(),
        'restaurant_id': _restaurantService.restaurantId,
        'sale_id': saleId,
        'reason': reason,
        'voided_by_user_id': _remoteSessionService.userId ?? voidedBy,
        'voided_at': DateTime.now().toUtc().toIso8601String(),
      });

      return AppSuccess(_saleFromRow({...saleRows.single, 'status': 'voided'}));
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'remote_sale_void_failed',
          message: 'No se pudo anular la venta en Supabase.',
          cause: error,
        ),
      );
    }
  }
}
