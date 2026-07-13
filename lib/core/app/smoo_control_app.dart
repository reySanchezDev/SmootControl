import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/navigation/app_router.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/theme/app_theme.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';
import 'package:smoo_control/features/auth/presentation/pages/auth_gate.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Root widget for the SmooControl application.
class SmooControlApp extends StatefulWidget {
  /// Creates the application root.
  const SmooControlApp({super.key});

  @override
  State<SmooControlApp> createState() => _SmooControlAppState();
}

class _SmooControlAppState extends State<SmooControlApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AuthBloc _authBloc;
  StreamSubscription<void>? _remoteSessionSubscription;

  @override
  void initState() {
    super.initState();
    _authBloc = serviceLocator<AuthBloc>()..add(const AuthSessionRequested());
    _remoteSessionSubscription = serviceLocator<CurrentRemoteSessionService>()
        .onExpired
        .listen((_) => _returnToLogin());
  }

  @override
  void dispose() {
    unawaited(_remoteSessionSubscription?.cancel());
    unawaited(_authBloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        navigatorKey: _navigatorKey,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        home: const AuthGate(),
        onGenerateRoute: onGenerateAppRoute,
        supportedLocales: const [Locale('es')],
        theme: AppTheme.light,
      ),
    );
  }

  /// Returns the app to the login gate when Supabase invalidates admin auth.
  void _returnToLogin() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    _authBloc.add(const AuthSignOutRequested());
    navigator.popUntil((route) => route.isFirst);
  }
}
