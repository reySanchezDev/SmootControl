import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/config/app_run_mode.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/navigation/app_router.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/theme/app_theme.dart';
import 'package:smoo_control/features/attendance/presentation/pages/time_clock_gate.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';
import 'package:smoo_control/features/auth/presentation/pages/auth_gate.dart';
import 'package:smoo_control/features/sync/domain/services/sync_scheduler_service.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Root widget for the SmooControl application.
class SmooControlApp extends StatefulWidget {
  /// Creates the application root.
  const SmooControlApp({super.key});

  @override
  State<SmooControlApp> createState() => _SmooControlAppState();
}

class _SmooControlAppState extends State<SmooControlApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AuthBloc _authBloc;
  StreamSubscription<void>? _remoteSessionSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool? _wasConnected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authBloc = serviceLocator<AuthBloc>()..add(const AuthSessionRequested());
    _remoteSessionSubscription = serviceLocator<CurrentRemoteSessionService>()
        .onExpired
        .listen((_) => _returnToLogin());
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    unawaited(_initializeConnectivity());
  }

  @override
  void dispose() {
    unawaited(_remoteSessionSubscription?.cancel());
    unawaited(_connectivitySubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authBloc.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(serviceLocator<SyncSchedulerService>().runAutomaticallyNow());
    }
  }

  Future<void> _initializeConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _wasConnected = _isConnected(results);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isConnected = _isConnected(results);
    final wasConnected = _wasConnected;
    _wasConnected = isConnected;
    if (isConnected && wasConnected == false) {
      unawaited(serviceLocator<SyncSchedulerService>().runAutomaticallyNow());
    }
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
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
        home: AppRunMode.isTimeClock ? const TimeClockGate() : const AuthGate(),
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
