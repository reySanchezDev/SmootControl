import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/navigation/app_router.dart';
import 'package:smoo_control/core/theme/app_theme.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';
import 'package:smoo_control/features/auth/presentation/pages/auth_gate.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Root widget for the SmooControl application.
class SmooControlApp extends StatelessWidget {
  /// Creates the application root.
  const SmooControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          serviceLocator<AuthBloc>()..add(const AuthSessionRequested()),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        home: const AuthGate(),
        onGenerateRoute: onGenerateAppRoute,
        supportedLocales: const [Locale('es')],
        theme: AppTheme.light,
      ),
    );
  }
}
