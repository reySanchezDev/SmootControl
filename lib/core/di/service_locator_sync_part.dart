part of 'service_locator.dart';

void _registerSalesAndSyncDependencies() {
  serviceLocator
    ..registerLazySingleton<LocalSalesDataSource>(
      () => LocalSalesDataSource(
        serviceLocator<AppDatabase>(),
        inventoryDataSource: serviceLocator<LocalInventoryDataSource>(),
        packagingDataSource: serviceLocator<LocalPackagingDataSource>(),
      ),
    )
    ..registerLazySingleton<ISalesRepository>(
      () => SalesRepository(
        serviceLocator<LocalSalesDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
        inventoryDataSource: serviceLocator<LocalInventoryDataSource>(),
        packagingDataSource: serviceLocator<LocalPackagingDataSource>(),
        currentOperatorService: serviceLocator<CurrentOperatorService>(),
      ),
    )
    ..registerLazySingleton<SupabaseSalesAdminRepository>(
      () => SupabaseSalesAdminRepository(
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerFactory<SalesBloc>(
      () => SalesBloc(
        repository: serviceLocator<SupabaseSalesAdminRepository>(),
        auditLogRepository: serviceLocator<SupabaseAdminRepository>(),
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
        database: serviceLocator<AppDatabase>(),
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerLazySingleton<SupabaseCatalogPullService>(
      () => SupabaseCatalogPullService(
        database: serviceLocator<AppDatabase>(),
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerLazySingleton<ICatalogPullService>(
      serviceLocator.get<SupabaseCatalogPullService>,
    )
    ..registerLazySingleton<PosDeviceNameService>(PosDeviceNameService.new)
    ..registerLazySingleton<RemoteBootstrapAuthService>(
      () => RemoteBootstrapAuthService(
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        deviceNameService: serviceLocator<PosDeviceNameService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerLazySingleton<DeviceInitializationService>(
      () => DeviceInitializationService(
        database: serviceLocator<AppDatabase>(),
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteAuthService: serviceLocator<RemoteBootstrapAuthService>(),
        catalogPullService: serviceLocator<SupabaseCatalogPullService>(),
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
}
