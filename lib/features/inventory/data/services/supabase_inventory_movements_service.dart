import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_movement_document.dart';

part 'supabase_inventory_movements_service_part.dart';

/// Reads inventory movement documents directly from Supabase for admin views.
final class SupabaseInventoryMovementsService {
  /// Creates the service.
  const SupabaseInventoryMovementsService({
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

  /// Loads movement headers inside an inclusive date range.
  Future<AppResult<List<InventoryMovementDocument>>> loadHeaders({
    required InventoryMovementDocumentType type,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final documents = <InventoryMovementDocument>[];
      final products = await _productNames();
      if (type == InventoryMovementDocumentType.all ||
          type == InventoryMovementDocumentType.adjustment) {
        documents.addAll(await _adjustmentHeaders(from, to));
      }
      if (type != InventoryMovementDocumentType.adjustment) {
        documents.addAll(await _genericHeaders(type, from, to, products));
      }
      documents.sort(_compareNewestFirst);
      return AppSuccess(documents);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'inventory_movements_read_failed',
          message: 'No se pudieron leer los movimientos de inventario.',
          cause: error,
        ),
      );
    }
  }

  /// Loads one movement detail.
  Future<AppResult<List<InventoryMovementDocumentLine>>> loadLines(
    InventoryMovementDocument document,
  ) async {
    try {
      final products = await _productNames();
      final lines = document.type == InventoryMovementDocumentType.adjustment
          ? await _adjustmentLines(document.id, products)
          : await _genericLines(document.id, products);
      return AppSuccess(lines);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'inventory_movement_detail_failed',
          message: 'No se pudo leer el detalle del movimiento.',
          cause: error,
        ),
      );
    }
  }

  Future<List<InventoryMovementDocument>> _adjustmentHeaders(
    DateTime from,
    DateTime to,
  ) async {
    final docs = await _getRows('inventory_adjustment_documents', {
      ..._rangeQuery(from, to),
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'select': 'id,document_number,note,created_at',
      'order': 'created_at.desc',
    });
    final lines = await _getRows('inventory_adjustment_lines', {
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'select': 'document_id,quantity_delta',
    });
    return docs.map((row) {
      final id = _text(row['id']);
      final docLines = lines.where((line) => _text(line['document_id']) == id);
      return InventoryMovementDocument(
        id: id,
        type: InventoryMovementDocumentType.adjustment,
        title: 'Ajuste #${_text(row['document_number'])}',
        createdAt: _date(row['created_at']),
        lineCount: docLines.length,
        quantityDelta: docLines.fold<double>(
          0,
          (sum, line) => sum + _decimal(line['quantity_delta']),
        ),
        note: _nullableText(row['note']),
      );
    }).toList();
  }

  Future<List<InventoryMovementDocument>> _genericHeaders(
    InventoryMovementDocumentType type,
    DateTime from,
    DateTime to,
    Map<String, String> products,
  ) async {
    final movements = await _genericMovementRows(type, from, to);
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final row in movements) {
      final key = _genericDocumentId(row);
      grouped.putIfAbsent(key, () => []).add(row);
    }
    return grouped.entries.map((entry) {
      final rows = entry.value;
      final first = rows.first;
      final docType = _typeFromText(_text(first['movement_type']));
      return InventoryMovementDocument(
        id: entry.key,
        type: docType,
        title: _genericTitle(docType, rows, products),
        createdAt: _date(first['created_at']),
        lineCount: rows.length,
        quantityDelta: rows.fold<double>(
          0,
          (sum, row) => sum + _decimal(row['quantity_delta']),
        ),
        note: _nullableText(first['notes']),
      );
    }).toList();
  }

  Future<List<InventoryMovementDocumentLine>> _adjustmentLines(
    String documentId,
    Map<String, String> products,
  ) async {
    final rows = await _getRows('inventory_adjustment_lines', {
      'document_id': 'eq.$documentId',
      'select': 'product_id,stock_before,counted_quantity,quantity_delta',
      'order': 'created_at.asc',
    });
    return rows
        .map(
          (row) => InventoryMovementDocumentLine(
            productName: products[_text(row['product_id'])] ?? 'Producto',
            quantityDelta: _decimal(row['quantity_delta']),
            stockBefore: _decimal(row['stock_before']),
            countedQuantity: _decimal(row['counted_quantity']),
          ),
        )
        .toList();
  }

  Future<List<InventoryMovementDocumentLine>> _genericLines(
    String documentId,
    Map<String, String> products,
  ) async {
    final rows = await _getRows('inventory_movements', {
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'select': 'id,product_id,quantity_delta,unit_cost,reference_id',
      'order': 'created_at.asc',
    });
    return rows.where((row) => _genericDocumentId(row) == documentId).map((
      row,
    ) {
      return InventoryMovementDocumentLine(
        productName: products[_text(row['product_id'])] ?? 'Producto',
        quantityDelta: _decimal(row['quantity_delta']),
        unitCostInCents: _moneyToCents(row['unit_cost']),
      );
    }).toList();
  }

  Future<List<Map<String, Object?>>> _genericMovementRows(
    InventoryMovementDocumentType type,
    DateTime from,
    DateTime to,
  ) {
    final query = {
      ..._rangeQuery(from, to),
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'select':
          'id,product_id,movement_type,quantity_delta,unit_cost,reference_type,'
          'reference_id,notes,created_at',
      'order': 'created_at.desc',
    };
    if (type == InventoryMovementDocumentType.all) {
      query['movement_type'] = 'neq.adjustment';
    } else {
      query['movement_type'] = 'eq.${_typeCode(type)}';
    }
    return _getRows('inventory_movements', query);
  }

  Future<Map<String, String>> _productNames() async {
    final rows = await _getRows('products', {
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'select': 'id,name',
    });
    return {for (final row in rows) _text(row['id']): _text(row['name'])};
  }

  Map<String, String> _rangeQuery(DateTime from, DateTime to) {
    final start = _startOfDay(from).toIso8601String();
    final end = _startOfDay(to).add(const Duration(days: 1)).toIso8601String();
    return {'and': '(created_at.gte.$start,created_at.lt.$end)'};
  }

  Future<List<Map<String, Object?>>> _getRows(
    String table,
    Map<String, String> query,
  ) async {
    final token = _remoteSessionService.accessToken;
    if (!_config.isConfigured ||
        !_restaurantService.isConfigured ||
        token == null) {
      throw StateError('Se requiere sesion remota administrativa.');
    }
    final response = await _client.get(
      _config.restUri(table, query),
      headers: {
        'apikey': _config.publishableKey,
        'authorization': 'Bearer $token',
        'accept': 'application/json',
      },
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      _remoteSessionService.expire();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Supabase rechazo lectura $table: ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<Object?, Object?>>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  String _text(Object? value) => value?.toString().trim() ?? '';
  String? _nullableText(Object? value) =>
      _text(value).isEmpty ? null : _text(value);
  double _decimal(Object? value) =>
      value is num ? value.toDouble() : double.tryParse(_text(value)) ?? 0;
  int _moneyToCents(Object? value) =>
      ((num.tryParse(_text(value)) ?? 0) * 100).round();
  DateTime _date(Object? value) =>
      DateTime.tryParse(_text(value)) ?? DateTime.now();
  String _genericDocumentId(Map<String, Object?> row) {
    final referenceId = _text(row['reference_id']);
    return [
      _text(row['movement_type']),
      _text(row['reference_type']),
      if (referenceId.isEmpty) _text(row['id']) else referenceId,
    ].join('|');
  }
}
