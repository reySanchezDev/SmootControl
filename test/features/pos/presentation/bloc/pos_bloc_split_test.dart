import 'package:bloc_test/bloc_test.dart';
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
import 'package:smoo_control/features/pos/domain/entities/account_split_draft.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_open_ticket_line.dart';
import 'package:smoo_control/features/pos/domain/repositories/i_pos_open_ticket_repository.dart';
import 'package:smoo_control/features/pos/domain/services/account_separation_service.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
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

part 'pos_bloc_split_fakes.dart';
part 'pos_bloc_split_selection_tests.dart';

void main() {
  group('PosBloc split accounts', () {
    _splitSelectionTests();

    blocTest<PosBloc, PosState>(
      'confirms split accounts when every cart item is assigned',
      build: _buildBloc,
      seed: () => const PosReady(
        products: [_product],
        tables: [_table],
        paymentMethods: [_cashMethod],
        cartLines: [PosCartLine(product: _product, quantity: 2)],
        selectedTableId: 'table-1',
        selectedPaymentMethodId: 'cash',
      ),
      act: (bloc) => bloc.add(
        const PosAccountsSplitConfirmed(_splitAccounts),
      ),
      expect: () => [
        isA<PosReady>()
            .having(
              (state) => state.splitAccounts.length,
              'split accounts',
              2,
            )
            .having(
              (state) => state.splitAccountsByTable['table-1']?.length,
              'split accounts by table',
              2,
            )
            .having((state) => state.cartLines, 'original cart', isEmpty)
            .having(
              (state) => state.splitSourceLinesByTable['table-1']?.length,
              'source lines',
              1,
            ),
      ],
    );

    blocTest<PosBloc, PosState>(
      'updates payment method and reference per split account',
      build: _buildBloc,
      seed: () => const PosReady(
        products: [_product],
        tables: [_table],
        paymentMethods: [_cashMethod, _transferMethod],
        cartLines: [PosCartLine(product: _product, quantity: 2)],
        splitAccounts: _splitAccounts,
        selectedTableId: 'table-1',
      ),
      act: (bloc) {
        bloc
          ..add(
            const PosSplitAccountPaymentSelected(
              accountId: 'account-2',
              paymentMethodId: 'transfer',
            ),
          )
          ..add(
            const PosSplitAccountReferenceChanged(
              accountId: 'account-2',
              reference: 'TRX-002',
            ),
          );
      },
      expect: () => [
        isA<PosReady>().having(
          (state) => state.splitAccounts.last.paymentMethodId,
          'payment method',
          'transfer',
        ),
        isA<PosReady>().having(
          (state) => state.splitAccounts.last.paymentReference,
          'payment reference',
          'TRX-002',
        ),
      ],
    );

    blocTest<PosBloc, PosState>(
      'rejects split accounts without selected table',
      build: _buildBloc,
      seed: () => const PosReady(
        products: [_product],
        tables: [_table],
        paymentMethods: [_cashMethod],
        cartLines: [PosCartLine(product: _product, quantity: 2)],
        selectedPaymentMethodId: 'cash',
      ),
      act: (bloc) => bloc.add(
        const PosAccountsSplitConfirmed(_splitAccounts),
      ),
      expect: () => [
        isA<PosFailure>().having(
          (state) => state.failure.code,
          'failure code',
          'split_table_required',
        ),
        isA<PosReady>(),
      ],
    );

    blocTest<PosBloc, PosState>(
      'saves one sale per split account on checkout',
      build: _buildBloc,
      seed: () => const PosReady(
        products: [_product],
        tables: [_table],
        paymentMethods: [_cashMethod, _transferMethod],
        cartLines: [PosCartLine(product: _product, quantity: 2)],
        splitAccounts: _splitAccountsWithPayments,
        selectedTableId: 'table-1',
      ),
      act: (bloc) => bloc.add(const PosCheckoutRequested()),
      expect: () => [
        isA<PosReady>()
            .having((state) => state.cartLines, 'cart', isEmpty)
            .having((state) => state.lastCompletedSales.length, 'sales', 2)
            .having(
              (state) => state.lastCompletedSales.first.paymentMethodId,
              'first payment',
              'cash',
            )
            .having(
              (state) => state.lastCompletedSales.last.paymentMethodId,
              'last payment',
              'transfer',
            )
            .having(
              (state) => state.lastCompletedSales.last.paymentReference,
              'last reference',
              'TRX-002',
            ),
      ],
    );
  });
}

const _product = Product(
  id: 'product-1',
  categoryId: 'category-1',
  name: 'Espresso',
  priceInCents: 350,
  costInCents: 100,
  isActive: true,
);
const _cashMethod = PaymentMethod(
  id: 'cash',
  name: 'Efectivo',
  affectsCashRegister: true,
  requiresReference: false,
  isActive: true,
);
const _transferMethod = PaymentMethod(
  id: 'transfer',
  name: 'Transferencia',
  affectsCashRegister: false,
  requiresReference: true,
  isActive: true,
);
const _table = RestaurantTable(
  id: 'table-1',
  name: 'Mesa 1',
  status: RestaurantTableStatus.available,
  isActive: true,
);
const _splitAccounts = [
  AccountSplitDraft(
    id: 'account-1',
    tableId: 'table-1',
    name: 'Ana',
    itemIds: ['product-1-0'],
  ),
  AccountSplitDraft(
    id: 'account-2',
    tableId: 'table-1',
    name: 'Luis',
    itemIds: ['product-1-1'],
  ),
];
const _splitAccountsWithPayments = [
  AccountSplitDraft(
    id: 'account-1',
    tableId: 'table-1',
    name: 'Ana',
    itemIds: ['product-1-0'],
    paymentMethodId: 'cash',
  ),
  AccountSplitDraft(
    id: 'account-2',
    tableId: 'table-1',
    name: 'Luis',
    itemIds: ['product-1-1'],
    paymentMethodId: 'transfer',
    paymentReference: 'TRX-002',
  ),
];

PosBloc _buildBloc() {
  final session = CashRegisterSession(
    id: 'cash-session-1',
    cashierId: 'cashier-1',
    businessDate: DateTime.now(),
    openingCashInCents: 10000,
    status: CashRegisterStatus.open,
  );
  return PosBloc(
    catalogRepository: _CatalogFake(),
    accountSeparationService: const AccountSeparationService(),
    productsRepository: _ProductsFake(),
    inventoryRepository: const _InventoryFake(),
    tablesRepository: _TablesFake(),
    paymentMethodsRepository: _PaymentMethodsFake(),
    modifiersRepository: const _ModifiersFake(),
    packagingRepository: const _PackagingRepositoryFake(),
    salesRepository: _SalesFake(),
    settingsRepository: _SettingsFake(),
    cashRegisterRepository: _CashFake(session),
    auditLogRepository: _AuditLogFake(),
    currentOperatorService: const CurrentOperatorService(),
    openTicketRepository: _PosOpenTicketFake(),
  );
}
