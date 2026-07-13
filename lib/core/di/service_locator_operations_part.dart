part of 'service_locator.dart';

void _registerOperationsDependencies() {
  serviceLocator
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
        repository: serviceLocator<SupabaseAdminExpensesRepository>(),
        auditLogRepository: serviceLocator<SupabaseAdminRepository>(),
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
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerLazySingleton<SupabaseDailySalesReportService>(
      () => SupabaseDailySalesReportService(
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerLazySingleton<SupabaseExpensesReportService>(
      () => SupabaseExpensesReportService(
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerLazySingleton<SupabaseMonthlyOperationalReportService>(
      () => SupabaseMonthlyOperationalReportService(
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerLazySingleton<SupabaseInventoryValueReportService>(
      () => SupabaseInventoryValueReportService(
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerLazySingleton<SupabaseCashRegisterAdminService>(
      () => SupabaseCashRegisterAdminService(
        client: serviceLocator<http.Client>(),
        config: serviceLocator<SupabaseAppConfig>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
      ),
    )
    ..registerFactory<ReportsBloc>(
      () => ReportsBloc(serviceLocator<ReportSummaryService>()),
    );
}
