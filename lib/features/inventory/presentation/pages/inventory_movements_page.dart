import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/inventory/data/services/supabase_inventory_movements_service.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_movement_document.dart';

part 'inventory_movements_widgets_part.dart';

/// Administrative browser for remote inventory movement documents.
class InventoryMovementsPage extends StatefulWidget {
  /// Creates the page.
  const InventoryMovementsPage({super.key});

  @override
  State<InventoryMovementsPage> createState() => _InventoryMovementsPageState();
}

class _InventoryMovementsPageState extends State<InventoryMovementsPage> {
  late Future<AppResult<List<InventoryMovementDocument>>> _future;
  InventoryMovementDocumentType _type = InventoryMovementDocumentType.all;
  late DateTime _from;
  late DateTime _to;

  SupabaseInventoryMovementsService get _service =>
      serviceLocator<SupabaseInventoryMovementsService>();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month);
    _to = DateTime(now.year, now.month, now.day);
    _reload();
  }

  void _reload() {
    _future = _service.loadHeaders(type: _type, from: _from, to: _to);
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Movimientos de inventario',
      body: Column(
        children: [
          _MovementFilters(
            from: _from,
            onChanged: _applyFilters,
            onReload: () => setState(_reload),
            to: _to,
            type: _type,
          ),
          Expanded(
            child: FutureBuilder<AppResult<List<InventoryMovementDocument>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const AppLoadingPage();
                return snapshot.data!.when(
                  success: _buildList,
                  failure: (error) => AppEmptyState(
                    icon: Icons.error_outline,
                    message: error.message,
                    title: 'No se pudo cargar',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<InventoryMovementDocument> documents) {
    if (documents.isEmpty) {
      return const AppEmptyState(
        icon: Icons.inventory_2_outlined,
        message: 'No hay movimientos para el filtro seleccionado.',
        title: 'Sin movimientos',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final document = documents[index];
        return _MovementHeaderTile(
          document: document,
          onTap: () => unawaited(_openDetail(document)),
        );
      },
      itemCount: documents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
    );
  }

  void _applyFilters(
    InventoryMovementDocumentType type,
    DateTime from,
    DateTime to,
  ) {
    setState(() {
      _type = type;
      _from = from;
      _to = to.isBefore(from) ? from : to;
      _reload();
    });
  }

  Future<void> _openDetail(InventoryMovementDocument document) async {
    await showModalBottomSheet<void>(
      context: context,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MovementDetailSheet(document: document),
    );
  }
}
