import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/navigation/app_routes.dart';
import 'package:smoo_control/core/navigation/route_access.dart';
import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_state.dart';
import 'package:smoo_control/features/auth/presentation/pages/login_page.dart';
import 'package:smoo_control/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:smoo_control/features/pos/presentation/pages/pos_page.dart';

/// Chooses the public login flow or the authenticated start page.
class AuthGate extends StatelessWidget {
  /// Creates the auth gate.
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return switch (state) {
          AuthInitial() => const AppLoadingPage(),
          AuthLoading() => const AppLoadingPage(),
          Authenticated(:final session) => _startPageFor(session),
          AuthInitialSetupRequired() => const LoginPage(setupRequired: true),
          AuthFailure(:final failure, :final setupRequired) => LoginPage(
            setupRequired: setupRequired,
            failure: failure.message,
          ),
          Unauthenticated() => const LoginPage(),
        };
      },
    );
  }

  Widget _startPageFor(AuthSession session) {
    if (session.isPosUser) {
      return RouteAccessGuard(
        anyPermissions: RouteAccess.anyPermissionsFor(AppRoutes.pos),
        child: const PosPage(),
      );
    }

    return const DashboardPage();
  }
}

/// Creates the root authentication BLoC and loads the current session.
class AuthGateProvider extends StatelessWidget {
  /// Creates the root authentication provider.
  const AuthGateProvider({required this.createBloc, super.key});

  /// Auth BLoC factory.
  final AuthBloc Function() createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => createBloc()..add(const AuthSessionRequested()),
      child: const AuthGate(),
    );
  }
}
