part of 'service_locator.dart';

void _registerCoreDependencies() {
  serviceLocator
    ..registerLazySingleton<SupabaseAppConfig>(SupabaseAppConfig.new)
    ..registerLazySingleton<CurrentRestaurantService>(
      CurrentRestaurantService.new,
    )
    ..registerLazySingleton<CurrentRemoteSessionService>(
      CurrentRemoteSessionService.new,
    )
    ..registerLazySingleton<http.Client>(
      http.Client.new,
      dispose: (client) => client.close(),
    )
    ..registerLazySingleton<AppDatabase>(
      () => AppDatabase(openDatabaseConnection()),
      dispose: (database) => database.close(),
    )
    ..registerLazySingleton<SupabaseAdminRepository>(
      () => SupabaseAdminRepository(
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        client: serviceLocator<http.Client>(),
      ),
    )
    ..registerLazySingleton<SupabaseAdminExpensesRepository>(
      () => SupabaseAdminExpensesRepository(
        config: serviceLocator<SupabaseAppConfig>(),
        restaurantService: serviceLocator<CurrentRestaurantService>(),
        remoteSessionService: serviceLocator<CurrentRemoteSessionService>(),
        client: serviceLocator<http.Client>(),
      ),
    );
}
