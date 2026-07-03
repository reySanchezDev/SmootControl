import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

/// Orders mobile POS table navigation with occupied tables first.
List<RestaurantTable> orderMobilePosTables({
  required Map<String, List<PosCartLine>> cartLinesByTable,
  required Map<String, List<AccountSplitDraft>> splitAccountsByTable,
  required List<RestaurantTable> tables,
}) {
  final occupied = <RestaurantTable>[];
  final free = <RestaurantTable>[];

  for (final table in tables) {
    if (_isMobileTableOccupied(
      cartLinesByTable: cartLinesByTable,
      splitAccountsByTable: splitAccountsByTable,
      table: table,
    )) {
      occupied.add(table);
    } else {
      free.add(table);
    }
  }

  occupied.sort(_compareMobileTableNames);
  free.sort(_compareMobileTableNames);

  return [...occupied, ...free];
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
    if (categoryChanged && !_productsVisible) {
      _productsVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = PosResponsiveLayout.fromConstraints(constraints);
        final catalog = PosCatalogPanel(state: widget.state);
        final ticket = PosTicketPanel(
          lines: widget.state.cartLines,
          salesTypes: widget.state.salesTypes,
          selectedSalesTypeId: widget.state.selectedSalesType?.id,
          onProductsVisibilityToggled: () {
            setState(() => _productsVisible = !_productsVisible);
          },
          productsVisible: _productsVisible,
        );
        final categoryBand = PosCategoryBand(
          onCategorySelected: _showProducts,
          state: widget.state,
        );
        final phoneLayout = layout.maxWidth < 560;
        final tableBand = phoneLayout
            ? _MobileTablesLauncher(state: widget.state)
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
              productsVisible: _productsVisible,
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

  Widget _buildCompactScrollContent({
    required Widget actionsBand,
    required Widget catalog,
    required Widget categoryBand,
    required bool includeActions,
    required bool includeCategories,
    required bool includeTables,
    required PosResponsiveLayout layout,
    required bool phoneLayout,
    required Widget tableBand,
    required Widget ticket,
    required double contentHeight,
  }) {
    final ticketHeight = layout.ticketHeight(
      lineCount: widget.state.cartLines.length,
      productsVisible: _productsVisible,
    );
    final catalogHeight = _productsVisible
        ? layout.catalogHeight(_visibleCatalogItemCount())
        : 0.0;
    final categoryHeight = layout.categoryBandHeight(
      _visibleRootCategoryCount(),
    );
    final tableHeight = phoneLayout
        ? 68.0
        : layout.tableBandHeight(_visibleTableEntryCount());
    final renderedCategoryHeight = includeCategories ? categoryHeight : 0.0;
    final renderedTableHeight = includeTables ? tableHeight : 0.0;
    final actionsHeight = includeActions ? layout.actionsHeight() : 0.0;
    final gapCount =
        (_productsVisible ? 2 : 0) +
        (includeCategories ? 1 : 0) +
        (includeTables ? 1 : 0) +
        (includeActions ? 1 : 0);
    final gapHeight = gapCount * 10.0;
    final naturalHeight =
        ticketHeight +
        catalogHeight +
        renderedCategoryHeight +
        renderedTableHeight +
        actionsHeight +
        gapHeight;
    final verticalPadding = phoneLayout ? 10.0 : 20.0;
    final availableContentHeight = (contentHeight - verticalPadding).clamp(
      0.0,
      double.infinity,
    );
    final expandedTicketHeight = naturalHeight < availableContentHeight
        ? ticketHeight + (availableContentHeight - naturalHeight)
        : ticketHeight;

    return ListView(
      key: const ValueKey('pos-compact-scroll'),
      padding: EdgeInsets.fromLTRB(10, 10, 10, phoneLayout ? 0 : 10),
      children: [
        SizedBox(height: expandedTicketHeight, child: ticket),
        if (_productsVisible) ...[
          const SizedBox(height: 10),
          SizedBox(height: catalogHeight, child: catalog),
          const SizedBox(height: 10),
        ],
        if (includeCategories)
          SizedBox(height: categoryHeight, child: categoryBand),
        if (includeTables) ...[
          const SizedBox(height: 10),
          SizedBox(height: tableHeight, child: tableBand),
        ],
        if (includeActions) ...[
          const SizedBox(height: 10),
          SizedBox(height: actionsHeight, child: actionsBand),
        ],
      ],
    );
  }

  void _showProducts() {
    if (_productsVisible) return;
    setState(() => _productsVisible = true);
  }

  int _visibleCatalogItemCount() {
    final categoryId = _activeCategoryId();
    return _categoriesFor(categoryId).length + _productsFor(categoryId);
  }

  int _visibleTableEntryCount() {
    final splitAccountCount = widget.state.splitAccountsByTable.values.fold(
      0,
      (sum, accounts) => sum + accounts.length,
    );
    return widget.state.tables.length + splitAccountCount;
  }

  int _visibleRootCategoryCount() {
    return widget.state.categories.where(_isRootCategory).length;
  }

  String? _activeCategoryId() {
    final selected = widget.state.selectedCategoryId;
    if (selected != null && _categoryById(selected) != null) return selected;

    final roots = widget.state.categories.where(_isRootCategory).toList()
      ..sort(_sortCategories);
    return roots.isEmpty ? null : roots.first.id;
  }

  List<ProductCategory> _categoriesFor(String? parentId) {
    if (parentId == null) return const [];
    return widget.state.categories.where((category) {
      return category.isActive && category.parentId == parentId;
    }).toList()..sort(_sortCategories);
  }

  int _productsFor(String? categoryId) {
    if (widget.state.categories.isEmpty) {
      return widget.state.products.where(_isVisibleProduct).length;
    }
    if (categoryId == null) return 0;
    return widget.state.products.where((product) {
      return _isVisibleProduct(product) && product.categoryId == categoryId;
    }).length;
  }

  ProductCategory? _categoryById(String id) {
    for (final category in widget.state.categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  bool _isRootCategory(ProductCategory category) {
    return category.isActive && category.parentId == null;
  }

  bool _isVisibleProduct(Product product) {
    return product.isActive && product.isAvailableInPos;
  }

  int _sortCategories(ProductCategory first, ProductCategory second) {
    return first.sortOrder.compareTo(second.sortOrder);
  }
}

class _PosMobileLayout extends StatelessWidget {
  const _PosMobileLayout({
    required this.actionsBand,
    required this.catalog,
    required this.categoryBand,
    required this.productsVisible,
    required this.tableBand,
    required this.ticket,
  });

  static const double _categoryBandHeight = 132;
  static const double _tableBandHeight = 68;
  static const double _actionsBandHeight = 76;

  final Widget actionsBand;
  final Widget catalog;
  final Widget categoryBand;
  final bool productsVisible;
  final Widget tableBand;
  final Widget ticket;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: productsVisible ? 5 : 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: ticket,
          ),
        ),
        if (productsVisible)
          Flexible(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: catalog,
            ),
          ),
        const Divider(height: 1),
        SizedBox(height: _categoryBandHeight, child: categoryBand),
        const Divider(height: 1),
        SizedBox(
          height: _tableBandHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: tableBand,
          ),
        ),
        const Divider(height: 1),
        SizedBox(height: _actionsBandHeight, child: actionsBand),
      ],
    );
  }
}

class _MobileTablesLauncher extends StatelessWidget {
  const _MobileTablesLauncher({required this.state});

  final PosReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final options = _orderedTableOptions();
    final selected = _selectedTableOption(options);
    final selectedLabel = selected?.label ?? _selectedTableLabel();
    final selectedOccupied = selected?.isOccupied ?? false;
    final canSwipe = options.length > 1;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: !canSwipe
          ? null
          : (details) => _handleHorizontalSwipe(context, options, details),
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: state.tables.isEmpty ? null : () => _openTablesSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.table_restaurant_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    reverseDuration: const Duration(milliseconds: 140),
                    transitionBuilder: (child, animation) {
                      final offsetAnimation =
                          Tween<Offset>(
                            begin: const Offset(.12, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          );
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: _MobileTableSelectionLabel(
                      key: ValueKey(selected?.id ?? selectedLabel ?? 'none'),
                      selectedLabel: selectedLabel,
                      title: l10n.moduleTables.toUpperCase(),
                    ),
                  ),
                ),
                if (selectedOccupied) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: colorScheme.error,
                    ),
                    child: Text(
                      l10n.tableOccupiedLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onError,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.keyboard_arrow_up, color: colorScheme.onSurface),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleHorizontalSwipe(
    BuildContext context,
    List<_MobileTableOption> options,
    DragEndDetails details,
  ) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 120) return;

    final selectedIndex = _selectedTableIndex(options);
    final direction = velocity < 0 ? 1 : -1;
    final nextIndex = (selectedIndex + direction) % options.length;
    final normalizedIndex = nextIndex < 0 ? options.length - 1 : nextIndex;
    context.read<PosBloc>().add(PosTableSelected(options[normalizedIndex].id));
  }

  int _selectedTableIndex(List<_MobileTableOption> options) {
    final tableId = state.selectedTableId;
    if (tableId == null) return 0;

    final index = options.indexWhere((option) => option.id == tableId);
    if (index < 0) return 0;
    return index;
  }

  _MobileTableOption? _selectedTableOption(List<_MobileTableOption> options) {
    if (options.isEmpty) return null;
    return options[_selectedTableIndex(options)];
  }

  List<_MobileTableOption> _orderedTableOptions() {
    final orderedTables = orderMobilePosTables(
      cartLinesByTable: state.cartLinesByTable,
      splitAccountsByTable: state.splitAccountsByTable,
      tables: state.tables,
    );
    return [
      for (final table in orderedTables)
        _MobileTableOption(
          id: table.id,
          isOccupied: _isMobileTableOccupied(
            cartLinesByTable: state.cartLinesByTable,
            splitAccountsByTable: state.splitAccountsByTable,
            table: table,
          ),
          label: table.operationalName,
        ),
    ];
  }

  String? _selectedTableLabel() {
    final tableId = state.selectedTableId;
    if (tableId == null) return null;

    final splitAccountId = state.selectedSplitAccountId;
    if (splitAccountId != null) {
      final accounts = state.splitAccountsByTable[tableId] ?? const [];
      for (final account in accounts) {
        if (account.id == splitAccountId) return account.name;
      }
    }

    for (final table in state.tables) {
      if (table.id == tableId) return table.operationalName;
    }
    return null;
  }

  void _openTablesSheet(BuildContext context) {
    final bloc = _maybePosBloc(context);
    final l10n = AppLocalizations.of(context);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) {
          final height = MediaQuery.sizeOf(sheetContext).height * .72;
          final sheet = SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: SizedBox(
                height: height,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.moduleTables,
                            style: Theme.of(sheetContext).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: PosTablesBand(
                        onEntrySelected: () => Navigator.of(sheetContext).pop(),
                        state: state,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          if (bloc == null) return sheet;
          return BlocProvider.value(value: bloc, child: sheet);
        },
      ),
    );
  }

  PosBloc? _maybePosBloc(BuildContext context) {
    try {
      return context.read<PosBloc>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

class _MobileTableSelectionLabel extends StatelessWidget {
  const _MobileTableSelectionLabel({
    required this.selectedLabel,
    required this.title,
    super.key,
  });

  final String? selectedLabel;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (selectedLabel != null)
          Text(
            selectedLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _MobileTableOption {
  const _MobileTableOption({
    required this.id,
    required this.isOccupied,
    required this.label,
  });

  final String id;
  final bool isOccupied;
  final String label;
}
