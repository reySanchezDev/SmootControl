import 'package:get_it/get_it.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/cash_register/domain/repositories/i_cash_register_repository.dart';
import 'package:smoo_control/features/catalog/domain/repositories/i_catalog_repository.dart';
import 'package:smoo_control/features/inventory/domain/repositories/i_inventory_repository.dart';
import 'package:smoo_control/features/modifiers/domain/repositories/i_modifiers_repository.dart';
import 'package:smoo_control/features/packaging/domain/repositories/i_packaging_repository.dart';
import 'package:smoo_control/features/payment_methods/domain/repositories/i_payment_methods_repository.dart';
import 'package:smoo_control/features/pos/data/datasources/local_pos_open_ticket_datasource.dart';
import 'package:smoo_control/features/pos/data/repositories/pos_open_ticket_repository.dart';
import 'package:smoo_control/features/pos/domain/repositories/i_pos_open_ticket_repository.dart';
import 'package:smoo_control/features/pos/domain/services/account_separation_service.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/products/domain/repositories/i_products_repository.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';
import 'package:smoo_control/features/settings/domain/repositories/i_business_settings_repository.dart';
import 'package:smoo_control/features/tables/domain/repositories/i_tables_repository.dart';

/// Registers POS dependencies.
void registerPosDependencies(GetIt locator) {
  locator
    ..registerLazySingleton<AccountSeparationService>(
      AccountSeparationService.new,
    )
    ..registerLazySingleton<LocalPosOpenTicketDataSource>(
      () => LocalPosOpenTicketDataSource(locator<AppDatabase>()),
    )
    ..registerLazySingleton<IPosOpenTicketRepository>(
      () => PosOpenTicketRepository(locator<LocalPosOpenTicketDataSource>()),
    )
    ..registerFactory<PosBloc>(
      () => PosBloc(
        catalogRepository: locator<ICatalogRepository>(),
        accountSeparationService: locator<AccountSeparationService>(),
        productsRepository: locator<IProductsRepository>(),
        inventoryRepository: locator<IInventoryRepository>(),
        modifiersRepository: locator<IModifiersRepository>(),
        tablesRepository: locator<ITablesRepository>(),
        paymentMethodsRepository: locator<IPaymentMethodsRepository>(),
        packagingRepository: locator<IPackagingRepository>(),
        salesRepository: locator<ISalesRepository>(),
        settingsRepository: locator<IBusinessSettingsRepository>(),
        cashRegisterRepository: locator<ICashRegisterRepository>(),
        auditLogRepository: locator<IAuditLogRepository>(),
        currentOperatorService: locator<CurrentOperatorService>(),
        openTicketRepository: locator<IPosOpenTicketRepository>(),
      ),
    );
}
