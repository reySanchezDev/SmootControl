import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_summary.dart';
import 'package:smoo_control/features/cash_register/domain/repositories/i_cash_register_repository.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/catalog/domain/repositories/i_catalog_repository.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_stock_item.dart';
import 'package:smoo_control/features/inventory/domain/repositories/i_inventory_repository.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_catalog.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';
import 'package:smoo_control/features/modifiers/domain/repositories/i_modifiers_repository.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_stock_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/product_packaging_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/packaging/domain/repositories/i_packaging_repository.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/payment_methods/domain/repositories/i_payment_methods_repository.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_open_ticket_line.dart';
import 'package:smoo_control/features/pos/domain/repositories/i_pos_open_ticket_repository.dart';
import 'package:smoo_control/features/pos/domain/services/account_separation_service.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_more_options_panel.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_payment_amount_dialog.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/repositories/i_products_repository.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_void.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';
import 'package:smoo_control/features/settings/domain/repositories/i_business_settings_repository.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/features/tables/domain/entities/table_account.dart';
import 'package:smoo_control/features/tables/domain/repositories/i_tables_repository.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'pos_bloc_fakes.dart';
part 'pos_bloc_cash_register_test_cases.dart';
part 'pos_bloc_cart_test_cases.dart';

void main() {
  group('PosBloc', () {
    const product = Product(
      id: 'product-1',
      categoryId: 'category-1',
      name: 'Espresso',
      priceInCents: 350,
      costInCents: 100,
      isActive: true,
    );
    const unavailableProduct = Product(
      id: 'product-2',
      categoryId: 'category-1',
      name: 'Almuerzo especial',
      priceInCents: 12000,
      costInCents: 6000,
      isActive: true,
      isAvailableInPos: false,
    );
    const subcategoryProduct = Product(
      id: 'product-3',
      categoryId: 'category-1-1',
      name: 'Espresso doble',
      priceInCents: 500,
      costInCents: 150,
      isActive: true,
    );
    const trackedOutOfStockProduct = Product(
      id: 'product-4',
      categoryId: 'category-1',
      name: 'Postre limitado',
      priceInCents: 8000,
      costInCents: 4000,
      isActive: true,
      tracksInventory: true,
    );
    const method = PaymentMethod(
      id: 'cash',
      name: 'Efectivo',
      affectsCashRegister: true,
      requiresReference: false,
      isActive: true,
    );
    const transferMethod = PaymentMethod(
      id: 'transfer',
      name: 'Transferencia',
      affectsCashRegister: false,
      requiresReference: true,
      isActive: true,
    );
    const category = ProductCategory(
      id: 'category-1',
      name: 'Cafe caliente',
      sortOrder: 1,
      isActive: true,
    );
    const subcategory = ProductCategory(
      id: 'category-1-1',
      name: 'Espressos',
      parentId: 'category-1',
      sortOrder: 1,
      isActive: true,
    );
    const unavailableCategory = ProductCategory(
      id: 'category-2',
      name: 'Latte',
      sortOrder: 2,
      isActive: true,
    );
    const unavailableSubcategory = ProductCategory(
      id: 'category-2-1',
      name: '16 oz',
      parentId: 'category-2',
      sortOrder: 1,
      isActive: true,
    );
    const table = RestaurantTable(
      id: 'table-1',
      name: 'Mesa 1',
      status: RestaurantTableStatus.available,
      isActive: true,
    );
    final cashSession = CashRegisterSession(
      id: 'cash-session-1',
      cashierId: 'cashier-1',
      businessDate: DateTime.now(),
      openingCashInCents: 10000,
      status: CashRegisterStatus.open,
    );
    late _SalesRepositoryFake sales;

    PosBloc buildBloc({
      ICashRegisterRepository? cashRegisterRepository,
      IPosOpenTicketRepository? openTicketRepository,
      IPaymentMethodsRepository? paymentMethodsRepository,
      ISalesRepository? salesRepository,
      IInventoryRepository? inventoryRepository,
    }) {
      return PosBloc(
        catalogRepository: const _CatalogRepositoryFake(
          categoriesResult: AppSuccess([
            category,
            subcategory,
            unavailableCategory,
            unavailableSubcategory,
          ]),
        ),
        accountSeparationService: const AccountSeparationService(),
        productsRepository: const _ProductsRepositoryFake(
          productsResult: AppSuccess([
            product,
            unavailableProduct,
            subcategoryProduct,
            trackedOutOfStockProduct,
          ]),
        ),
        inventoryRepository:
            inventoryRepository ?? const _InventoryRepositoryFake(),
        tablesRepository: const _TablesRepositoryFake(
          tablesResult: AppSuccess([table]),
        ),
        paymentMethodsRepository:
            paymentMethodsRepository ??
            const _PaymentMethodsRepositoryFake(
              methodsResult: AppSuccess([method, transferMethod]),
            ),
        modifiersRepository: const _ModifiersRepositoryFake(),
        packagingRepository: const _PackagingRepositoryFake(),
        salesRepository: salesRepository ?? _SalesRepositoryFake(),
        settingsRepository: _BusinessSettingsRepositoryFake(),
        cashRegisterRepository:
            cashRegisterRepository ?? _CashRegisterRepositoryFake(cashSession),
        auditLogRepository: _AuditLogRepositoryFake(),
        currentOperatorService: const CurrentOperatorService(),
        openTicketRepository:
            openTicketRepository ?? _PosOpenTicketRepositoryFake(),
      );
    }

    blocTest<PosBloc, PosState>(
      'loads products and payment methods',
      build: buildBloc,
      act: (bloc) => bloc.add(const PosStarted()),
      expect: () => [
        const PosLoading(),
        isA<PosReady>()
            .having(
              (state) => state.visibleCategories,
              'root categories',
              [category, unavailableCategory],
            )
            .having(
              (state) => state.products,
              'products',
              [product, subcategoryProduct],
            )
            .having((state) => state.tables, 'tables', [table])
            .having(
              (state) => state.selectedTableId,
              'selected table',
              table.id,
            )
            .having(
              (state) => state.paymentMethods,
              'methods',
              [method, transferMethod],
            ),
      ],
    );

    blocTest<PosBloc, PosState>(
      'hides inventory-tracked products without stock in POS',
      build: () => buildBloc(
        inventoryRepository: _InventoryRepositoryFake(
          stockResult: AppSuccess([
            InventoryStockItem(
              productId: 'product-4',
              productName: 'Postre limitado',
              quantityOnHand: 0,
              updatedAt: DateTime(2026, 7),
            ),
          ]),
        ),
      ),
      act: (bloc) => bloc.add(const PosStarted()),
      expect: () => [
        const PosLoading(),
        isA<PosReady>().having(
          (state) => state.products.map((product) => product.id),
          'visible product ids',
          isNot(contains('product-4')),
        ),
      ],
    );

    blocTest<PosBloc, PosState>(
      'requires closing a previous open cash register before opening today',
      build: () {
        final previousSession = CashRegisterSession(
          id: 'cash-session-yesterday',
          cashierId: 'cashier-1',
          businessDate: DateTime(2026),
          openingCashInCents: 10000,
          status: CashRegisterStatus.open,
        );
        return buildBloc(
          cashRegisterRepository: _CashRegisterRepositoryFake(
            previousSession,
          ),
        );
      },
      act: (bloc) => bloc.add(const PosStarted()),
      expect: () => [
        const PosLoading(),
        isA<PosStaleCashRegisterRequired>().having(
          (state) => state.session.id,
          'session id',
          'cash-session-yesterday',
        ),
      ],
    );

    late _PosOpenTicketRepositoryFake staleOpenTickets;
    blocTest<PosBloc, PosState>(
      'clears stale open table tickets after closing a previous cash register',
      build: () {
        final previousSession = CashRegisterSession(
          id: 'cash-session-yesterday',
          cashierId: 'cashier-1',
          businessDate: DateTime(2026),
          openingCashInCents: 10000,
          status: CashRegisterStatus.open,
        );
        staleOpenTickets = _PosOpenTicketRepositoryFake(
          tickets: [
            const PosOpenTicketLine(
              lineKey: 'product-1',
              tableId: 'table-1',
              productId: 'product-1',
              quantity: 2,
            ),
          ],
        );
        return buildBloc(
          cashRegisterRepository: _CashRegisterRepositoryFake(
            previousSession,
          ),
          openTicketRepository: staleOpenTickets,
        );
      },
      seed: () => PosStaleCashRegisterRequired(
        CashRegisterSession(
          id: 'cash-session-yesterday',
          cashierId: 'cashier-1',
          businessDate: DateTime(2026),
          openingCashInCents: 10000,
          status: CashRegisterStatus.open,
        ),
      ),
      act: (bloc) => bloc.add(
        const PosCashRegisterClosed(physicalClosingCashInCents: 10000),
      ),
      expect: () => [
        const PosLoading(),
        const PosCashRegisterRequired(),
      ],
      verify: (_) async {
        final result = await staleOpenTickets.getOpenTickets();
        switch (result) {
          case AppSuccess(:final value):
            expect(value, isEmpty);
          case AppFailureResult():
            fail('Open tickets should be readable in this test.');
        }
      },
    );

    blocTest<PosBloc, PosState>(
      'shows subcategories and direct products when category is selected',
      build: buildBloc,
      seed: () => const PosReady(
        categories: [category, subcategory],
        products: [product, subcategoryProduct],
        tables: [table],
        paymentMethods: [method],
        selectedPaymentMethodId: 'cash',
      ),
      act: (bloc) => bloc.add(const PosCategorySelected('category-1')),
      expect: () => [
        isA<PosReady>()
            .having(
              (state) => state.visibleCategories,
              'visible categories',
              [subcategory],
            )
            .having(
              (state) => state.visibleProducts,
              'visible products',
              [product],
            ),
      ],
    );

    blocTest<PosBloc, PosState>(
      'refreshes modifier catalog without leaving POS',
      build: buildBloc,
      seed: () => const PosReady(
        products: [product],
        tables: [table],
        paymentMethods: [method],
      ),
      act: (bloc) => bloc.add(
        const PosModifierCatalogRefreshed(
          ModifierCatalog(
            groups: [
              ModifierGroup(id: 'modifier-sides', name: 'Guarniciones'),
            ],
            options: [
              ModifierOption(
                id: 'option-1',
                groupId: 'modifier-sides',
                name: 'Frijoles fritos',
              ),
            ],
          ),
        ),
      ),
      expect: () => [
        isA<PosReady>().having(
          (state) => state.modifierCatalog.options.single.name,
          'refreshed modifier option',
          'Frijoles fritos',
        ),
      ],
    );

    blocTest<PosBloc, PosState>(
      'updates the temporary table name shown in POS',
      build: buildBloc,
      seed: () => const PosReady(
        products: [product],
        tables: [table],
        paymentMethods: [method],
      ),
      act: (bloc) => bloc.add(
        const PosTableDisplayNameChanged(
          tableId: 'table-1',
          displayName: 'Juan',
        ),
      ),
      expect: () => [
        isA<PosReady>().having(
          (state) => state.tables.single.displayName,
          'table display name',
          'Juan',
        ),
      ],
    );

    blocTest<PosBloc, PosState>(
      'restores the internal table name when the selected order is cleared',
      build: buildBloc,
      seed: () => const PosReady(
        products: [product],
        tables: [
          RestaurantTable(
            id: 'table-1',
            name: 'Mesa 1',
            displayName: 'Juan',
            status: RestaurantTableStatus.available,
            isActive: true,
          ),
        ],
        paymentMethods: [method],
        cartLines: [PosCartLine(product: product, quantity: 1)],
        cartLinesByTable: {
          'table-1': [PosCartLine(product: product, quantity: 1)],
        },
        selectedTableId: 'table-1',
      ),
      act: (bloc) => bloc.add(const PosCartCleared()),
      expect: () => [
        isA<PosReady>()
            .having((state) => state.cartLines, 'cart lines', isEmpty)
            .having(
              (state) => state.tables.single.displayName,
              'table display name',
              isNull,
            ),
      ],
    );

    blocTest<PosBloc, PosState>(
      'keeps active category branches visible without available products',
      build: buildBloc,
      seed: () => const PosReady(
        categories: [
          category,
          subcategory,
          unavailableCategory,
          unavailableSubcategory,
        ],
        products: [product, unavailableProduct],
        tables: [table],
        paymentMethods: [method],
        selectedPaymentMethodId: 'cash',
      ),
      act: (bloc) => bloc.add(const PosCategorySelected('category-2')),
      expect: () => [
        isA<PosReady>()
            .having(
              (state) => state.visibleCategories,
              'available subcategories',
              [unavailableSubcategory],
            )
            .having(
              (state) => state.visibleProducts,
              'empty unavailable products',
              isEmpty,
            ),
      ],
    );

    registerCartTests(
      buildBloc: buildBloc,
      method: method,
      product: product,
      table: table,
    );

    blocTest<PosBloc, PosState>(
      'saves checkout and clears cart',
      build: buildBloc,
      seed: () => const PosReady(
        products: [product],
        tables: [table],
        paymentMethods: [method],
        cartLines: [PosCartLine(product: product, quantity: 1)],
        selectedTableId: 'table-1',
        selectedPaymentMethodId: 'cash',
      ),
      act: (bloc) => bloc.add(const PosCheckoutRequested()),
      expect: () => [
        isA<PosReady>()
            .having((state) => state.cartLines, 'cart', isEmpty)
            .having(
              (state) => state.lastCompletedSale?.tableId,
              'table id',
              'table-1',
            )
            .having(
              (state) => state.lastCompletedSale?.invoiceNumber,
              'invoice number',
              'F-1',
            )
            .having(
              (state) => state.lastCompletedSale?.cashRegisterSessionId,
              'cash register session',
              'cash-session-1',
            )
            .having((state) => state.lastCompletedSale, 'sale', isNotNull),
      ],
    );

    blocTest<PosBloc, PosState>(
      'keeps POS ready when checkout save fails',
      build: () => buildBloc(
        salesRepository: _FailingSalesRepositoryFake(
          const AppFailure(
            code: 'packaging_stock_insufficient',
            message: 'Stock insuficiente de empaque: Bandeja.',
          ),
        ),
      ),
      seed: () => PosReady(
        products: const [product],
        tables: const [table],
        paymentMethods: const [method],
        cartLines: const [PosCartLine(product: product, quantity: 1)],
        selectedTableId: 'table-1',
        selectedPaymentMethodId: 'cash',
        openCashRegisterSession: cashSession,
      ),
      act: (bloc) => bloc.add(const PosCheckoutRequested()),
      expect: () => [
        isA<PosFailure>().having(
          (state) => state.failure.message,
          'message',
          'Stock insuficiente de empaque: Bandeja.',
        ),
        isA<PosReady>()
            .having((state) => state.cartLines, 'cart preserved', hasLength(1))
            .having(
              (state) => state.selectedTableId,
              'table preserved',
              'table-1',
            )
            .having(
              (state) => state.selectedPaymentMethodId,
              'payment preserved',
              'cash',
            )
            .having(
              (state) => state.openCashRegisterSession?.id,
              'cash register preserved',
              'cash-session-1',
            ),
      ],
    );

    blocTest<PosBloc, PosState>(
      'adds a new pending row when the same served product is added again',
      build: buildBloc,
      seed: () => const PosReady(
        products: [product],
        tables: [table],
        paymentMethods: [method],
        cartLines: [
          PosCartLine(
            product: product,
            quantity: 1,
            isServed: true,
            ticketLineId: 'served-line',
          ),
        ],
        selectedTableId: 'table-1',
        selectedPaymentMethodId: 'cash',
      ),
      act: (bloc) => bloc.add(const PosProductAdded(product)),
      expect: () => [
        isA<PosReady>()
            .having((state) => state.cartLines.length, 'visual rows', 2)
            .having(
              (state) => state.cartLines.first.isServed,
              'served row preserved',
              isTrue,
            )
            .having(
              (state) => state.cartLines.last.isServed,
              'new row pending',
              isFalse,
            ),
      ],
    );

    blocTest<PosBloc, PosState>(
      'consolidates equal visual rows when saving checkout',
      build: () {
        sales = _SalesRepositoryFake();
        return buildBloc(salesRepository: sales);
      },
      seed: () => const PosReady(
        products: [product],
        tables: [table],
        paymentMethods: [method],
        cartLines: [
          PosCartLine(
            product: product,
            quantity: 1,
            isServed: true,
            ticketLineId: 'served-line',
          ),
          PosCartLine(
            product: product,
            quantity: 2,
            ticketLineId: 'pending-line',
          ),
        ],
        selectedTableId: 'table-1',
        selectedPaymentMethodId: 'cash',
      ),
      act: (bloc) => bloc.add(const PosCheckoutRequested()),
      expect: () => [isA<PosReady>()],
      verify: (_) {
        final items = sales.savedItemsBySaleId.values.single;
        expect(items, hasLength(1));
        expect(items.single.quantity, 3);
      },
    );

    blocTest<PosBloc, PosState>(
      'ignores duplicate checkout requests while a sale is being saved',
      build: () {
        sales = _BlockingSalesRepositoryFake();
        return buildBloc(salesRepository: sales);
      },
      seed: () => PosReady(
        products: const [product],
        tables: const [table],
        paymentMethods: const [method],
        cartLines: const [PosCartLine(product: product, quantity: 1)],
        cartLinesByTable: const {
          'table-1': [PosCartLine(product: product, quantity: 1)],
        },
        selectedTableId: 'table-1',
        selectedPaymentMethodId: 'cash',
        openCashRegisterSession: cashSession,
      ),
      act: (bloc) async {
        bloc
          ..add(const PosCheckoutRequested())
          ..add(const PosCheckoutRequested());
        final blockingSales = sales as _BlockingSalesRepositoryFake;
        await blockingSales.firstSaveStarted.future;
        blockingSales.complete();
      },
      wait: const Duration(milliseconds: 10),
      expect: () => [isA<PosReady>()],
      verify: (_) {
        expect(sales.savedItemsBySaleId, hasLength(1));
      },
    );

    testWidgets(
      'charges Cordoba from compact more options payment flow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const cashRoot = PaymentMethod(
          id: 'cash-root',
          name: 'Efectivo',
          affectsCashRegister: false,
          requiresReference: false,
          isActive: true,
          isPaymentTarget: false,
        );
        const cordoba = PaymentMethod(
          id: 'cash-nio',
          parentId: 'cash-root',
          name: 'Cordoba',
          groupName: 'Efectivo',
          currencyCode: 'NIO',
          affectsCashRegister: true,
          requiresReference: false,
          isActive: true,
          displayOrder: 10,
        );

        sales = _SalesRepositoryFake();
        final bloc = buildBloc(
          salesRepository: sales,
          paymentMethodsRepository: const _PaymentMethodsRepositoryFake(
            methodsResult: AppSuccess([cashRoot, cordoba]),
          ),
        );
        addTearDown(bloc.close);

        final readyLoaded = bloc.stream.firstWhere(
          (state) => state is PosReady,
        );
        bloc.add(const PosStarted());
        await readyLoaded;

        final productAdded = bloc.stream.firstWhere(
          (state) => state is PosReady && state.cartLines.isNotEmpty,
        );
        bloc.add(const PosProductAdded(product));
        await productAdded;

        final ready = bloc.state as PosReady;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider.value(
              value: bloc,
              child: Scaffold(
                body: PosMoreOptionsPanel(
                  compactOperationalMode: true,
                  onPaymentParentChanged: (_) {},
                  state: ready,
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Efectivo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cordoba'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(PosPaymentAmountDialog), findsOneWidget);

        final saleCompleted = bloc.stream.firstWhere(
          (state) => state is PosReady && state.lastCompletedSale != null,
        );
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await saleCompleted;

        expect(sales.savedItemsBySaleId, hasLength(1));
        expect(find.byType(PosPaymentAmountDialog), findsNothing);
      },
    );

    blocTest<PosBloc, PosState>(
      'restores table cart after entering POS again',
      build: () {
        return buildBloc(
          openTicketRepository: _PosOpenTicketRepositoryFake(
            tickets: [
              const PosOpenTicketLine(
                lineKey: 'product-1',
                tableId: 'table-1',
                productId: 'product-1',
                quantity: 2,
              ),
            ],
          ),
        );
      },
      act: (bloc) => bloc.add(const PosStarted()),
      expect: () => [
        const PosLoading(),
        isA<PosReady>()
            .having(
              (state) => state.cartLines.single.quantity,
              'selected table restored quantity on start',
              2,
            )
            .having(
              (state) => state.selectedTableId,
              'selected table',
              table.id,
            ),
      ],
    );

    blocTest<PosBloc, PosState>(
      'does not close cash register with pending products on any table',
      build: buildBloc,
      seed: () => PosReady(
        products: const [product],
        tables: const [table],
        paymentMethods: const [method],
        cartLinesByTable: const {
          'table-1': [PosCartLine(product: product, quantity: 1)],
        },
        selectedTableId: 'table-2',
        selectedPaymentMethodId: 'cash',
        openCashRegisterSession: cashSession,
      ),
      act: (bloc) => bloc.add(
        const PosCashRegisterClosed(physicalClosingCashInCents: 10000),
      ),
      expect: () => [
        isA<PosFailure>().having(
          (state) => state.failure.code,
          'failure code',
          'pos_close_cash_pending_cart',
        ),
        isA<PosReady>(),
      ],
    );

    registerCashRegisterCheckoutTests(
      buildBloc: buildBloc,
      method: method,
      product: product,
      table: table,
    );
  });
}
