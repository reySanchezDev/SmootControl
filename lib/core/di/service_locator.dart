import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/database/open_database_connection.dart';
import 'package:smoo_control/core/di/register_auth_dependencies.dart';
import 'package:smoo_control/core/di/register_pos_dependencies.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/audit/data/datasources/local_audit_log_datasource.dart';
import 'package:smoo_control/features/audit/data/repositories/audit_log_repository.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/audit/presentation/bloc/audit_log_bloc.dart';
import 'package:smoo_control/features/cash_register/data/datasources/local_cash_register_datasource.dart';
import 'package:smoo_control/features/cash_register/data/repositories/cash_register_repository.dart';
import 'package:smoo_control/features/cash_register/domain/repositories/i_cash_register_repository.dart';
import 'package:smoo_control/features/cash_register/presentation/bloc/cash_register_bloc.dart';
import 'package:smoo_control/features/catalog/data/datasources/local_catalog_datasource.dart';
import 'package:smoo_control/features/catalog/data/repositories/catalog_repository.dart';
import 'package:smoo_control/features/catalog/domain/repositories/i_catalog_repository.dart';
import 'package:smoo_control/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:smoo_control/features/exchange_rates/data/datasources/local_exchange_rate_datasource.dart';
import 'package:smoo_control/features/exchange_rates/data/repositories/exchange_rate_repository.dart';
import 'package:smoo_control/features/exchange_rates/domain/repositories/i_exchange_rate_repository.dart';
import 'package:smoo_control/features/expenses/data/datasources/local_expenses_datasource.dart';
import 'package:smoo_control/features/expenses/data/repositories/expenses_repository.dart';
import 'package:smoo_control/features/expenses/domain/repositories/i_expenses_repository.dart';
import 'package:smoo_control/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:smoo_control/features/modifiers/data/datasources/local_modifiers_datasource.dart';
import 'package:smoo_control/features/modifiers/data/repositories/modifiers_repository.dart';
import 'package:smoo_control/features/modifiers/domain/repositories/i_modifiers_repository.dart';
import 'package:smoo_control/features/modifiers/presentation/bloc/modifiers_bloc.dart';
import 'package:smoo_control/features/payment_methods/data/datasources/local_payment_methods_datasource.dart';
import 'package:smoo_control/features/payment_methods/data/repositories/payment_methods_repository.dart';
import 'package:smoo_control/features/payment_methods/domain/repositories/i_payment_methods_repository.dart';
import 'package:smoo_control/features/payment_methods/presentation/bloc/payment_methods_bloc.dart';
import 'package:smoo_control/features/products/data/datasources/local_products_datasource.dart';
import 'package:smoo_control/features/products/data/repositories/products_repository.dart';
import 'package:smoo_control/features/products/domain/repositories/i_products_repository.dart';
import 'package:smoo_control/features/products/presentation/bloc/products_bloc.dart';
import 'package:smoo_control/features/reports/data/services/supabase_report_summary_service.dart';
import 'package:smoo_control/features/reports/domain/services/i_remote_report_summary_service.dart';
import 'package:smoo_control/features/reports/domain/services/report_summary_service.dart';
import 'package:smoo_control/features/reports/presentation/bloc/reports_bloc.dart';
import 'package:smoo_control/features/roles/data/datasources/local_roles_datasource.dart';
import 'package:smoo_control/features/roles/data/repositories/roles_repository.dart';
import 'package:smoo_control/features/roles/domain/repositories/i_roles_repository.dart';
import 'package:smoo_control/features/roles/domain/services/access_control_service.dart';
import 'package:smoo_control/features/roles/domain/services/access_seed_service.dart';
import 'package:smoo_control/features/roles/presentation/bloc/roles_bloc.dart';
import 'package:smoo_control/features/sales/data/datasources/local_sales_datasource.dart';
import 'package:smoo_control/features/sales/data/repositories/sales_repository.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';
import 'package:smoo_control/features/sales/domain/services/sale_invoice_pdf_service.dart';
import 'package:smoo_control/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:smoo_control/features/settings/data/datasources/local_business_settings_datasource.dart';
import 'package:smoo_control/features/settings/data/repositories/business_settings_repository.dart';
import 'package:smoo_control/features/settings/domain/repositories/i_business_settings_repository.dart';
import 'package:smoo_control/features/settings/presentation/bloc/business_settings_bloc.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_settings_datasource.dart';
import 'package:smoo_control/features/sync/data/datasources/supabase_catalog_pull_service.dart';
import 'package:smoo_control/features/sync/data/datasources/supabase_sync_remote_sender.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_settings_repository.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_settings_repository.dart';
import 'package:smoo_control/features/sync/domain/services/admin_data_refresh_service.dart';
import 'package:smoo_control/features/sync/domain/services/i_catalog_pull_service.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';
import 'package:smoo_control/features/sync/domain/services/sync_queue_processor.dart';
import 'package:smoo_control/features/sync/domain/services/sync_scheduler_service.dart';
import 'package:smoo_control/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:smoo_control/features/tables/data/datasources/local_tables_datasource.dart';
import 'package:smoo_control/features/tables/data/repositories/tables_repository.dart';
import 'package:smoo_control/features/tables/domain/repositories/i_tables_repository.dart';
import 'package:smoo_control/features/tables/presentation/bloc/tables_bloc.dart';
import 'package:smoo_control/features/users/data/datasources/local_users_datasource.dart';
import 'package:smoo_control/features/users/data/repositories/users_repository.dart';
import 'package:smoo_control/features/users/domain/repositories/i_users_repository.dart';
import 'package:smoo_control/features/users/presentation/bloc/users_bloc.dart';

/// Global dependency container for the application.
final GetIt serviceLocator = GetIt.instance;

/// Registers application dependencies.
Future<void> configureDependencies() async {
  await serviceLocator.reset();
  serviceLocator
    ..registerLazySingleton<SupabaseAppConfig>(SupabaseAppConfig.new)
    ..registerLazySingleton<CurrentRestaurantService>(
      CurrentRestaurantService.new,
    )
    ..registerLazySingleton<http.Client>(
      http.Client.new,
      dispose: (client) => client.close(),
    )
    ..registerLazySingleton<AppDatabase>(
      () => AppDatabase(openDatabaseConnection()),
      dispose: (database) => database.close(),
    )
    ..registerLazySingleton<LocalCatalogDataSource>(
      () => LocalCatalogDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<ICatalogRepository>(
      () => CatalogRepository(
        serviceLocator<LocalCatalogDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
        remoteSender: serviceLocator<ISyncRemoteSender>(),
      ),
    )
    ..registerFactory<CatalogBloc>(
      () => CatalogBloc(
        repository: serviceLocator<ICatalogRepository>(),
        auditLogRepository: serviceLocator<IAuditLogRepository>(),
        remoteRefreshService: serviceLocator<AdminDataRefreshService>(),
      ),
    )
    ..registerLazySingleton<LocalProductsDataSource>(
      () => LocalProductsDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<IProductsRepository>(
      () => ProductsRepository(
        serviceLocator<LocalProductsDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
        remoteSender: serviceLocator<ISyncRemoteSender>(),
      ),
    )
    ..registerFactory<ProductsBloc>(
      () => ProductsBloc(
        repository: serviceLocator<IProductsRepository>(),
        auditLogRepository: serviceLocator<IAuditLogRepository>(),
        remoteRefreshService: serviceLocator<AdminDataRefreshService>(),
      ),
    )
    ..registerLazySingleton<LocalModifiersDataSource>(
      () => LocalModifiersDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<IModifiersRepository>(
      () => ModifiersRepository(
        serviceLocator<LocalModifiersDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
        remoteSender: serviceLocator<ISyncRemoteSender>(),
      ),
    )
    ..registerFactory<ModifiersBloc>(
      () => ModifiersBloc(
        repository: serviceLocator<IModifiersRepository>(),
        auditLogRepository: serviceLocator<IAuditLogRepository>(),
        remoteRefreshService: serviceLocator<AdminDataRefreshService>(),
      ),
    )
    ..registerLazySingleton<LocalPaymentMethodsDataSource>(
      () => LocalPaymentMethodsDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<IPaymentMethodsRepository>(
      () => PaymentMethodsRepository(
        serviceLocator<LocalPaymentMethodsDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
        remoteSender: serviceLocator<ISyncRemoteSender>(),
      ),
    )
    ..registerFactory<PaymentMethodsBloc>(
      () => PaymentMethodsBloc(
        repository: serviceLocator<IPaymentMethodsRepository>(),
        auditLogRepository: serviceLocator<IAuditLogRepository>(),
        remoteRefreshService: serviceLocator<AdminDataRefreshService>(),
      ),
    )
    ..registerLazySingleton<LocalTablesDataSource>(
      () => LocalTablesDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<ITablesRepository>(
      () => TablesRepository(
        serviceLocator<LocalTablesDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
        remoteSender: serviceLocator<ISyncRemoteSender>(),
      ),
    )
    ..registerFactory<TablesBloc>(
      () => TablesBloc(
        repository: serviceLocator<ITablesRepository>(),
        auditLogRepository: serviceLocator<IAuditLogRepository>(),
        remoteRefreshService: serviceLocator<AdminDataRefreshService>(),
      ),
    )
    ..registerLazySingleton<LocalCashRegisterDataSource>(
      () => LocalCashRegisterDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<ICashRegisterRepository>(
      () => CashRegisterRepository(
        serviceLocator<LocalCashRegisterDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
      ),
    )
    ..registerFactory<CashRegisterBloc>(
      () => CashRegisterBloc(
        repository: serviceLocator<ICashRegisterRepository>(),
        auditLogRepository: serviceLocator<IAuditLogRepository>(),
      ),
    )
    ..registerLazySingleton<LocalExpensesDataSource>(
      () => LocalExpensesDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<IExpensesRepository>(
      () => ExpensesRepository(
        serviceLocator<LocalExpensesDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
        remoteSender: serviceLocator<ISyncRemoteSender>(),
      ),
    )
    ..registerFactory<ExpensesBloc>(
      () => ExpensesBloc(
        repository: serviceLocator<IExpensesRepository>(),
        auditLogRepository: serviceLocator<IAuditLogRepository>(),
        remoteRefreshService: serviceLocator<AdminDataRefreshService>(),
      ),
    )
    ..registerLazySingleton<LocalExchangeRateDataSource>(
      () => LocalExchangeRateDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<IExchangeRateRepository>(
      () => ExchangeRateRepository(
        serviceLocator<LocalExchangeRateDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
        remoteSender: serviceLocator<ISyncRemoteSender>(),
      ),
    )
    ..registerLazySingleton<ReportSummaryService>(
      () => ReportSummaryService(
        cashRegisterRepository: serviceLocator<ICashRegisterRepository>(),
        salesRepository: serviceLocator<ISalesRepository>(),
        expensesRepository: serviceLocator<IExpensesRepository>(),
        remoteReportSummaryService:
            serviceLocator<IRemoteReportSummaryService>(),
      ),
    )
    ..registerLazySingleton<IRemoteReportSummaryService>(
      () => SupabaseReportSummaryService(
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerFactory<ReportsBloc>(
      () => ReportsBloc(serviceLocator<ReportSummaryService>()),
    )
    ..registerLazySingleton<LocalBusinessSettingsDataSource>(
      () => LocalBusinessSettingsDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<IBusinessSettingsRepository>(
      () => BusinessSettingsRepository(
        serviceLocator<LocalBusinessSettingsDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
      ),
    )
    ..registerFactory<BusinessSettingsBloc>(
      () => BusinessSettingsBloc(
        repository: serviceLocator<IBusinessSettingsRepository>(),
        auditLogRepository: serviceLocator<IAuditLogRepository>(),
        remoteRefreshService: serviceLocator<AdminDataRefreshService>(),
      ),
    )
    ..registerLazySingleton<LocalRolesDataSource>(
      () => LocalRolesDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<IRolesRepository>(
      () => RolesRepository(
        serviceLocator<LocalRolesDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
      ),
    )
    ..registerLazySingleton<AccessControlService>(
      () => AccessControlService(serviceLocator<IRolesRepository>()),
    )
    ..registerLazySingleton<AccessSeedService>(
      () => AccessSeedService(serviceLocator<IRolesRepository>()),
    )
    ..registerFactory<RolesBloc>(
      () => RolesBloc(
        repository: serviceLocator<IRolesRepository>(),
        seedService: serviceLocator<AccessSeedService>(),
        auditLogRepository: serviceLocator<IAuditLogRepository>(),
        remoteRefreshService: serviceLocator<AdminDataRefreshService>(),
      ),
    )
    ..registerLazySingleton<LocalUsersDataSource>(
      () => LocalUsersDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<IUsersRepository>(
      () => UsersRepository(
        serviceLocator<LocalUsersDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
      ),
    )
    ..registerFactory<UsersBloc>(
      () => UsersBloc(
        usersRepository: serviceLocator<IUsersRepository>(),
        rolesRepository: serviceLocator<IRolesRepository>(),
        seedService: serviceLocator<AccessSeedService>(),
        auditLogRepository: serviceLocator<IAuditLogRepository>(),
        remoteRefreshService: serviceLocator<AdminDataRefreshService>(),
      ),
    )
    ..registerLazySingleton<LocalAuditLogDataSource>(
      () => LocalAuditLogDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<IAuditLogRepository>(
      () => AuditLogRepository(
        serviceLocator<LocalAuditLogDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
      ),
    )
    ..registerFactory<AuditLogBloc>(
      () => AuditLogBloc(serviceLocator<IAuditLogRepository>()),
    )
    ..registerLazySingleton<SaleInvoicePdfService>(SaleInvoicePdfService.new)
    ..registerLazySingleton<LocalSalesDataSource>(
      () => LocalSalesDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<ISalesRepository>(
      () => SalesRepository(
        serviceLocator<LocalSalesDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
      ),
    )
    ..registerFactory<SalesBloc>(
      () => SalesBloc(
        repository: serviceLocator<ISalesRepository>(),
        auditLogRepository: serviceLocator<IAuditLogRepository>(),
      ),
    )
    ..registerLazySingleton<LocalSyncQueueDataSource>(
      () => LocalSyncQueueDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<LocalSyncSettingsDataSource>(
      () => LocalSyncSettingsDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<ISyncSettingsRepository>(
      () => SyncSettingsRepository(
        serviceLocator<LocalSyncSettingsDataSource>(),
      ),
    )
    ..registerLazySingleton<ISyncRemoteSender>(
      () => SupabaseSyncRemoteSender(
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerLazySingleton<ICatalogPullService>(
      () => SupabaseCatalogPullService(
        database: serviceLocator<AppDatabase>(),
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerLazySingleton<AdminDataRefreshService>(
      () => AdminDataRefreshService(serviceLocator<ICatalogPullService>()),
    )
    ..registerLazySingleton<ISyncQueueRepository>(
      () => SyncQueueRepository(
        serviceLocator<LocalSyncQueueDataSource>(),
        remoteSender: serviceLocator<ISyncRemoteSender>(),
        settingsRepository: serviceLocator<ISyncSettingsRepository>(),
      ),
    )
    ..registerLazySingleton<SyncQueueProcessor>(
      () => SyncQueueProcessor(
        repository: serviceLocator<ISyncQueueRepository>(),
        remoteSender: serviceLocator<ISyncRemoteSender>(),
      ),
    )
    ..registerLazySingleton<SyncSchedulerService>(
      () => SyncSchedulerService(
        settingsRepository: serviceLocator<ISyncSettingsRepository>(),
        processor: serviceLocator<SyncQueueProcessor>(),
      ),
      dispose: (scheduler) => scheduler.dispose(),
    )
    ..registerFactory<SyncBloc>(
      () => SyncBloc(
        repository: serviceLocator<ISyncQueueRepository>(),
        settingsRepository: serviceLocator<ISyncSettingsRepository>(),
        processor: serviceLocator<SyncQueueProcessor>(),
        scheduler: serviceLocator<SyncSchedulerService>(),
      ),
    );

  registerAuthDependencies(serviceLocator);
  registerPosDependencies(serviceLocator);
}
