import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_open_ticket_line.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';

/// Data model for locally persisted open POS ticket lines.
final class PosOpenTicketLineModel extends Equatable {
  /// Creates an open ticket line model.
  const PosOpenTicketLineModel({
    required this.id,
    required this.tableId,
    required this.lineKey,
    required this.productId,
    required this.quantity,
    required this.isServed,
    required this.selectedOptions,
  });

  /// Creates a model from a POS cart line.
  factory PosOpenTicketLineModel.fromLine({
    required String tableId,
    required PosCartLine line,
  }) {
    return PosOpenTicketLineModel(
      id: '$tableId::${line.lineKey}',
      tableId: tableId,
      lineKey: line.lineKey,
      productId: line.product.id,
      quantity: line.quantity,
      isServed: line.isServed,
      selectedOptions: line.selectedOptions,
    );
  }

  /// Creates a model from a local Drift row.
  factory PosOpenTicketLineModel.fromLocal(LocalPosOpenTicketLine row) {
    final selectedOptions = _decodeOptions(row.selectedOptionsJson);
    final lineKey = row.lineKey.isEmpty
        ? _lineKeyFromId(row.id, selectedOptions)
        : row.lineKey;
    return PosOpenTicketLineModel(
      id: row.id,
      tableId: row.tableId,
      lineKey: lineKey,
      productId: row.productId,
      quantity: row.quantity,
      isServed: row.isServed,
      selectedOptions: selectedOptions,
    );
  }

  /// Stable row identifier.
  final String id;

  /// Table that owns this line.
  final String tableId;

  /// Stable visual row identifier.
  final String lineKey;

  /// Product selected in the POS.
  final String productId;

  /// Stored quantity.
  final int quantity;

  /// Whether the line has been served.
  final bool isServed;

  /// Selected product options.
  final List<SelectedProductOption> selectedOptions;

  /// Converts this model to a domain entity.
  PosOpenTicketLine toEntity() {
    return PosOpenTicketLine(
      lineKey: lineKey,
      tableId: tableId,
      productId: productId,
      quantity: quantity,
      isServed: isServed,
      selectedOptions: selectedOptions,
    );
  }

  /// Converts this model to a Drift insert companion.
  LocalPosOpenTicketLinesCompanion toCompanion({
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return LocalPosOpenTicketLinesCompanion.insert(
      id: id,
      tableId: tableId,
      lineKey: drift.Value(lineKey),
      productId: productId,
      selectedOptionsJson: _encodeOptions(selectedOptions),
      quantity: quantity,
      isServed: drift.Value(isServed),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static String _encodeOptions(List<SelectedProductOption> options) {
    return jsonEncode([
      for (final option in options)
        {
          'groupName': option.groupName,
          'optionName': option.optionName,
        },
    ]);
  }

  static List<SelectedProductOption> _decodeOptions(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map)
          SelectedProductOption(
            groupName: item['groupName']?.toString() ?? '',
            optionName: item['optionName']?.toString() ?? '',
          ),
    ];
  }

  static String _lineKeyFromId(
    String id,
    List<SelectedProductOption> selectedOptions,
  ) {
    final separator = id.indexOf('::');
    final value = separator == -1 ? id : id.substring(separator + 2);
    if (selectedOptions.isEmpty && value.endsWith('|')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  @override
  List<Object?> get props => [
    id,
    tableId,
    lineKey,
    productId,
    quantity,
    isServed,
    selectedOptions,
  ];
}
