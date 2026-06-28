import 'package:get_it/get_it.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/auth/data/repositories/local_auth_repository.dart';
import 'package:smoo_control/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/roles/domain/services/access_seed_service.dart';

/// Registers auth and current operator dependencies.
void registerAuthDependencies(GetIt locator) {
  locator
    ..registerLazySingleton<CurrentOperatorService>(CurrentOperatorService.new)
    ..registerLazySingleton<IAuthRepository>(
      () => LocalAuthRepository(
        database: locator<AppDatabase>(),
        seedService: locator<AccessSeedService>(),
        currentOperatorService: locator<CurrentOperatorService>(),
      ),
    )
    ..registerFactory<AuthBloc>(() => AuthBloc(locator<IAuthRepository>()));
}
