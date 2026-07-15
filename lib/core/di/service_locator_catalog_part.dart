part of 'service_locator.dart';

void _registerCatalogDependencies() {
  serviceLocator
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
        repository: serviceLocator<SupabaseAdminRepository>(),
        auditLogRepository: serviceLocator<SupabaseAdminRepository>(),
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
        repository: serviceLocator<SupabaseAdminRepository>(),
        auditLogRepository: serviceLocator<SupabaseAdminRepository>(),
      ),
    )
    ..registerLazySingleton<LocalInventoryDataSource>(
      () => LocalInventoryDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<IInventoryRepository>(
      () => InventoryRepository(
        serviceLocator<LocalInventoryDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
        remoteSender: serviceLocator<ISyncRemoteSender>(),
      ),
    )
    ..registerLazySingleton<SupabaseInventoryAdminReadService>(
      () => SupabaseInventoryAdminReadService(
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerLazySingleton<SupabaseInventoryAdminWriteService>(
      () => SupabaseInventoryAdminWriteService(
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerLazySingleton<SupabaseInventoryMovementsService>(
      () => SupabaseInventoryMovementsService(
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerLazySingleton<LocalPackagingDataSource>(
      () => LocalPackagingDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<IPackagingRepository>(
      () => PackagingRepository(
        serviceLocator<LocalPackagingDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
        remoteSender: serviceLocator<ISyncRemoteSender>(),
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
        repository: serviceLocator<SupabaseAdminRepository>(),
        auditLogRepository: serviceLocator<SupabaseAdminRepository>(),
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
        repository: serviceLocator<SupabaseAdminRepository>(),
        auditLogRepository: serviceLocator<SupabaseAdminRepository>(),
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
        repository: serviceLocator<SupabaseAdminRepository>(),
        auditLogRepository: serviceLocator<SupabaseAdminRepository>(),
      ),
    );
}
