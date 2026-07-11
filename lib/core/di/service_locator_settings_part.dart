part of 'service_locator.dart';

void _registerSettingsAndAdminDependencies() {
  serviceLocator
    ..registerLazySingleton<LocalBusinessSettingsDataSource>(
      () => LocalBusinessSettingsDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<LocalStaffDataSource>(
      () => LocalStaffDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<StaffPosRepository>(
      () => StaffPosRepository(
        serviceLocator<LocalStaffDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
      ),
    )
    ..registerLazySingleton<IStaffRepository>(
      serviceLocator.get<StaffPosRepository>,
    )
    ..registerLazySingleton<SupabaseStaffAdminRepository>(
      () => SupabaseStaffAdminRepository(
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerLazySingleton<IBusinessSettingsRepository>(
      () => BusinessSettingsRepository(
        serviceLocator<LocalBusinessSettingsDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
        remoteSender: serviceLocator<ISyncRemoteSender>(),
      ),
    )
    ..registerFactory<BusinessSettingsBloc>(
      () => BusinessSettingsBloc(
        repository: serviceLocator<SupabaseAdminRepository>(),
        auditLogRepository: serviceLocator<SupabaseAdminRepository>(),
      ),
    )
    ..registerLazySingleton<LocalRolesDataSource>(
      () => LocalRolesDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<IRolesRepository>(
      () => RolesRepository(
        serviceLocator<LocalRolesDataSource>(),
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
        repository: serviceLocator<SupabaseAdminRepository>(),
        seedService: serviceLocator<AccessSeedService>(),
        auditLogRepository: serviceLocator<SupabaseAdminRepository>(),
        seedDefaults: false,
      ),
    )
    ..registerLazySingleton<LocalUsersDataSource>(
      () => LocalUsersDataSource(serviceLocator<AppDatabase>()),
    )
    ..registerLazySingleton<IUsersRepository>(
      () => UsersRepository(
        serviceLocator<LocalUsersDataSource>(),
        syncQueueRepository: serviceLocator<ISyncQueueRepository>(),
        remoteSender: serviceLocator<ISyncRemoteSender>(),
      ),
    )
    ..registerFactory<UsersBloc>(
      () => UsersBloc(
        usersRepository: serviceLocator<SupabaseAdminRepository>(),
        rolesRepository: serviceLocator<SupabaseAdminRepository>(),
        seedService: serviceLocator<AccessSeedService>(),
        auditLogRepository: serviceLocator<SupabaseAdminRepository>(),
        seedDefaults: false,
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
      () => AuditLogBloc(serviceLocator<SupabaseAdminRepository>()),
    )
    ..registerLazySingleton<SaleInvoicePdfService>(SaleInvoicePdfService.new)
    ..registerLazySingleton<PilotOperationResetService>(
      () => PilotOperationResetService(
        database: serviceLocator<AppDatabase>(),
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        client: serviceLocator<http.Client>(),
      ),
    );
}
