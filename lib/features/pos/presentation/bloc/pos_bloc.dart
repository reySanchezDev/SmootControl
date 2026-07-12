import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/cash_register/domain/repositories/i_cash_register_repository.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/catalog/domain/repositories/i_catalog_repository.dart';
import 'package:smoo_control/features/inventory/domain/repositories/i_inventory_repository.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_catalog.dart';
import 'package:smoo_control/features/modifiers/domain/repositories/i_modifiers_repository.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/packaging/domain/repositories/i_packaging_repository.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/payment_methods/domain/repositories/i_payment_methods_repository.dart';
import 'package:smoo_control/features/pos/data/datasources/local_pos_product_order_datasource.dart';
import 'package:smoo_control/features/pos/domain/entities/account_split_draft.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_open_ticket_line.dart';
import 'package:smoo_control/features/pos/domain/repositories/i_pos_open_ticket_repository.dart';
import 'package:smoo_control/features/pos/domain/services/account_separation_service.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/repositories/i_products_repository.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item_draft.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';
import 'package:smoo_control/features/settings/domain/repositories/i_business_settings_repository.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/features/tables/domain/entities/table_account.dart';
import 'package:smoo_control/features/tables/domain/repositories/i_tables_repository.dart';
import 'package:uuid/uuid.dart';
part 'pos_checkout_handlers.dart';
part 'pos_checkout_helpers.dart';
part 'pos_sale_item_builders.dart';
part 'pos_bulk_split_checkout_handlers.dart';
part 'pos_split_checkout_handlers.dart';
part 'pos_cash_register_handlers.dart';
part 'pos_cart_handlers.dart';
part 'pos_split_handlers.dart';
part 'pos_start_handlers.dart';
part 'pos_table_handlers.dart';
part 'pos_handler_registration.dart';

/// BLoC for basic POS checkout.
final class PosBloc extends Bloc<PosEvent, PosState> {
  /// Creates a POS BLoC.
  PosBloc({
    required ICatalogRepository catalogRepository,
    required AccountSeparationService accountSeparationService,
    required IProductsRepository productsRepository,
    required IInventoryRepository inventoryRepository,
    required IModifiersRepository modifiersRepository,
    required ITablesRepository tablesRepository,
    required IPaymentMethodsRepository paymentMethodsRepository,
    required IPackagingRepository packagingRepository,
    required ISalesRepository salesRepository,
    required IBusinessSettingsRepository settingsRepository,
    required ICashRegisterRepository cashRegisterRepository,
    required IAuditLogRepository auditLogRepository,
    required CurrentOperatorService currentOperatorService,
    required IPosOpenTicketRepository openTicketRepository,
    required IPosProductOrderDataSource productOrderDataSource,
  }) : _catalogRepository = catalogRepository,
       _accountSeparationService = accountSeparationService,
       _productsRepository = productsRepository,
       _inventoryRepository = inventoryRepository,
       _modifiersRepository = modifiersRepository,
       _tablesRepository = tablesRepository,
       _paymentMethodsRepository = paymentMethodsRepository,
       _packagingRepository = packagingRepository,
       _salesRepository = salesRepository,
       _settingsRepository = settingsRepository,
       _cashRegisterRepository = cashRegisterRepository,
       _auditLogRepository = auditLogRepository,
       _currentOperatorService = currentOperatorService,
       _openTicketRepository = openTicketRepository,
       _productOrderDataSource = productOrderDataSource,
       super(const PosInitial()) {
    _registerPosHandlers(this);
  }

  final ICatalogRepository _catalogRepository;
  final AccountSeparationService _accountSeparationService;
  final IProductsRepository _productsRepository;
  final IInventoryRepository _inventoryRepository;
  final IModifiersRepository _modifiersRepository;
  final ITablesRepository _tablesRepository;
  final IPaymentMethodsRepository _paymentMethodsRepository;
  final IPackagingRepository _packagingRepository;
  final ISalesRepository _salesRepository;
  final IBusinessSettingsRepository _settingsRepository;
  final ICashRegisterRepository _cashRegisterRepository;
  final IAuditLogRepository _auditLogRepository;
  final CurrentOperatorService _currentOperatorService;
  final IPosOpenTicketRepository _openTicketRepository;
  final IPosProductOrderDataSource _productOrderDataSource;
  bool _checkoutInProgress = false;

  void _onCategorySelected(
    PosCategorySelected event,
    Emitter<PosState> emit,
  ) {
    final current = state;
    if (current is! PosReady) return;

    emit(
      current.copyWith(
        selectedCategoryId: event.categoryId,
        clearSelectedCategory: event.categoryId == null,
        clearLastCompletedSale: true,
      ),
    );
  }

  void _onPaymentMethodSelected(
    PosPaymentMethodSelected event,
    Emitter<PosState> emit,
  ) {
    final current = state;
    if (current is! PosReady) return;

    emit(
      current.copyWith(
        selectedPaymentMethodId: event.paymentMethodId,
        clearLastCompletedSale: true,
      ),
    );
  }

  Future<void> _onProductsReordered(
    PosProductsReordered event,
    Emitter<PosState> emit,
  ) async {
    final current = state;
    if (current is! PosReady) return;

    final orderByProductId = await _productOrderDataSource.saveCategoryOrder(
      categoryId: event.categoryId,
      productIds: event.productIds,
    );
    emit(
      current.copyWith(
        productOrderByProductId: orderByProductId,
        clearLastCompletedSale: true,
      ),
    );
  }

  Future<void> _onProductOrderReset(
    PosProductOrderReset event,
    Emitter<PosState> emit,
  ) async {
    final current = state;
    if (current is! PosReady) return;

    final orderByProductId = await _productOrderDataSource.resetCategoryOrder(
      event.categoryId,
    );
    emit(
      current.copyWith(
        productOrderByProductId: orderByProductId,
        clearLastCompletedSale: true,
      ),
    );
  }

  Future<void> _onTablesReordered(
    PosTablesReordered event,
    Emitter<PosState> emit,
  ) async {
    final current = state;
    if (current is! PosReady) return;

    final orderByTableId = await _productOrderDataSource.saveTableOrder(
      tableIds: event.tableIds,
    );
    emit(
      current.copyWith(
        tableOrderByTableId: orderByTableId,
        clearLastCompletedSale: true,
      ),
    );
  }

  void _onModifierCatalogRefreshed(
    PosModifierCatalogRefreshed event,
    Emitter<PosState> emit,
  ) {
    final current = state;
    if (current is! PosReady) return;

    emit(
      current.copyWith(
        modifierCatalog: event.catalog,
        clearLastCompletedSale: true,
      ),
    );
  }

  void _onSplitAccountPaymentSelected(
    PosSplitAccountPaymentSelected event,
    Emitter<PosState> emit,
  ) {
    final current = state;
    if (current is! PosReady) return;

    PaymentMethod? method;
    for (final candidate in current.paymentMethods) {
      if (candidate.id == event.paymentMethodId) {
        method = candidate;
        break;
      }
    }

    emit(
      current.copyWith(
        splitAccounts: [
          for (final account in current.splitAccounts)
            if (account.id == event.accountId)
              account.copyWith(
                paymentMethodId: event.paymentMethodId,
                clearPaymentReference: !(method?.requiresReference ?? false),
              )
            else
              account,
        ],
        clearLastCompletedSale: true,
      ),
    );
  }

  void _onSplitAccountReferenceChanged(
    PosSplitAccountReferenceChanged event,
    Emitter<PosState> emit,
  ) {
    final current = state;
    if (current is! PosReady) return;

    emit(
      current.copyWith(
        splitAccounts: [
          for (final account in current.splitAccounts)
            if (account.id == event.accountId)
              account.copyWith(paymentReference: event.reference)
            else
              account,
        ],
        clearLastCompletedSale: true,
      ),
    );
  }
}
