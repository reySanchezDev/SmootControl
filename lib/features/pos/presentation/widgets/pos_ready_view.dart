import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/theme/app_palette.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/pos/domain/entities/account_split_draft.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_actions_band.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_catalog_panel.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_category_band.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_responsive_layout.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_tables_band.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_ticket_panel.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'pos_ready_mobile_layout_part.dart';
part 'pos_ready_state_helpers_part.dart';
part 'pos_ready_mobile_tables_launcher_part.dart';
part 'pos_ready_mobile_tables_sheet_part.dart';

/// Orders mobile POS table navigation using local visual preferences first.
List<RestaurantTable> orderMobilePosTables({
  required Map<String, List<PosCartLine>> cartLinesByTable,
  required Map<String, List<AccountSplitDraft>> splitAccountsByTable,
  required Map<String, int> tableOrderByTableId,
  required List<RestaurantTable> tables,
}) {
  final ordered = [...tables]
    ..sort((first, second) {
      final firstOrder = tableOrderByTableId[first.id];
      final secondOrder = tableOrderByTableId[second.id];
      if (firstOrder != null && secondOrder != null) {
        final order = firstOrder.compareTo(secondOrder);
        if (order != 0) return order;
      }
      if (firstOrder != null) return -1;
      if (secondOrder != null) return 1;
      return _compareMobileTableNames(first, second);
    });
  return ordered;
}

bool _isMobileTableOccupied({
  required Map<String, List<PosCartLine>> cartLinesByTable,
  required Map<String, List<AccountSplitDraft>> splitAccountsByTable,
  required RestaurantTable table,
}) {
  final hasCart = cartLinesByTable[table.id]?.isNotEmpty ?? false;
  final hasSplitAccounts = splitAccountsByTable[table.id]?.isNotEmpty ?? false;
  return hasCart ||
      hasSplitAccounts ||
      table.status == RestaurantTableStatus.occupied;
}

int _compareMobileTableNames(RestaurantTable first, RestaurantTable second) {
  final firstNumber = _firstNumber(first.name);
  final secondNumber = _firstNumber(second.name);
  if (firstNumber != null && secondNumber != null) {
    final numberOrder = firstNumber.compareTo(secondNumber);
    if (numberOrder != 0) return numberOrder;
  }
  return first.name.compareTo(second.name);
}

int? _firstNumber(String value) {
  final match = RegExp(r'\d+').firstMatch(value);
  return match == null ? null : int.tryParse(match.group(0)!);
}

/// Ready state content for the POS page.
class PosReadyView extends StatefulWidget {
  /// Creates the ready POS view.
  const PosReadyView({required this.state, super.key});

  /// Current POS ready state.
  final PosReady state;

  @override
  State<PosReadyView> createState() => _PosReadyViewState();
}

class _PosReadyViewState extends State<PosReadyView> {
  String? _paymentParentKey;
  bool _productsVisible = true;
  bool _mobileCatalogMode = false;

  @override
  void didUpdateWidget(covariant PosReadyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final completedSaleChanged =
        oldWidget.state.lastCompletedSale?.id !=
        widget.state.lastCompletedSale?.id;
    if (completedSaleChanged && widget.state.lastCompletedSale != null) {
      _paymentParentKey = null;
    }
    final categoryChanged =
        oldWidget.state.selectedCategoryId != widget.state.selectedCategoryId;
    if (categoryChanged) {
      _mobileCatalogMode = true;
      _productsVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = PosResponsiveLayout.fromConstraints(constraints);
        final phoneLayout = layout.maxWidth < 560;
        final productsVisible = phoneLayout
            ? _mobileCatalogMode
            : _productsVisible;
        final catalog = PosCatalogPanel(state: widget.state);
        final ticket = PosTicketPanel(
          lines: widget.state.cartLines,
          salesTypes: widget.state.salesTypes,
          selectedSalesTypeId: widget.state.selectedSalesType?.id,
          onProductsVisibilityToggled: _toggleProductsVisibility,
          showMobileTotalBand: !phoneLayout,
          productsVisible: productsVisible,
        );
        final categoryBand = PosCategoryBand(
          onCategorySelected: phoneLayout
              ? _enterMobileCatalogMode
              : _showProducts,
          state: widget.state,
        );
        final tableBand = phoneLayout
            ? _MobileTablesLauncher(
                catalogMode: _mobileCatalogMode,
                onCatalogModeToggled: _toggleMobileCatalogMode,
                state: widget.state,
              )
            : PosTablesBand(state: widget.state);
        final actionsBand = PosActionsBand(
          onPaymentParentChanged: (parentKey) {
            setState(() => _paymentParentKey = parentKey);
          },
          paymentParentKey: _paymentParentKey,
          state: widget.state,
        );

        if (layout.compact) {
          if (phoneLayout) {
            return _PosMobileLayout(
              actionsBand: actionsBand,
              catalog: catalog,
              categoryBand: categoryBand,
              categoryHeight: layout.mobileCategoryBandHeight(
                _visibleRootCategoryCount(),
              ),
              mobileCatalogMode: _mobileCatalogMode,
              productsVisible: productsVisible,
              tableBand: tableBand,
              ticket: ticket,
            );
          }

          return _buildCompactScrollContent(
            actionsBand: actionsBand,
            catalog: catalog,
            categoryBand: categoryBand,
            contentHeight: constraints.maxHeight,
            includeActions: true,
            includeCategories: true,
            includeTables: true,
            layout: layout,
            phoneLayout: false,
            tableBand: tableBand,
            ticket: ticket,
          );
        }

        return Column(
          children: [
            Expanded(child: ticket),
            if (_productsVisible) ...[
              const Divider(height: 1),
              SizedBox(
                height: layout.catalogHeight(_visibleCatalogItemCount()),
                child: catalog,
              ),
            ],
            const Divider(height: 1),
            SizedBox(
              height: layout.categoryBandHeight(_visibleRootCategoryCount()),
              child: categoryBand,
            ),
            const Divider(height: 1),
            SizedBox(height: layout.wideTableBandHeight(), child: tableBand),
            const Divider(height: 1),
            SizedBox(height: layout.wideActionsHeight(), child: actionsBand),
          ],
        );
      },
    );
  }

  void _showProducts() {
    if (_productsVisible) return;
    setState(() => _productsVisible = true);
  }

  void _toggleProductsVisibility() {
    if (_mobileCatalogMode) return;
    setState(() => _productsVisible = !_productsVisible);
  }

  void _toggleMobileCatalogMode() {
    setState(() {
      _mobileCatalogMode = !_mobileCatalogMode;
      _productsVisible = _mobileCatalogMode;
    });
  }

  void _enterMobileCatalogMode() {
    if (_mobileCatalogMode && _productsVisible) return;
    setState(() {
      _mobileCatalogMode = true;
      _productsVisible = true;
    });
  }
}
