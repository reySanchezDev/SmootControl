import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/attendance/presentation/pages/time_clock_page.dart';
import 'package:smoo_control/features/auth/domain/services/device_initialization_service.dart';
import 'package:smoo_control/features/auth/presentation/pages/device_initialization_page.dart';

/// Startup gate for the standalone attendance APK.
final class TimeClockGate extends StatefulWidget {
  /// Creates the time-clock gate.
  const TimeClockGate({super.key});

  @override
  State<TimeClockGate> createState() => _TimeClockGateState();
}

class _TimeClockGateState extends State<TimeClockGate> {
  late Future<AppResult<DeviceStartupMode>> _future;

  @override
  void initState() {
    super.initState();
    _future = _startupMode();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppResult<DeviceStartupMode>>(
      future: _future,
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result == null) return const AppLoadingPage();
        return switch (result) {
          AppFailureResult(:final error) => AppEmptyState(
            icon: Icons.error_outline,
            message: error.message,
            title: 'Marcador',
          ),
          AppSuccess(:final value) => _pageFor(value),
        };
      },
    );
  }

  Widget _pageFor(DeviceStartupMode mode) {
    return switch (mode) {
      DeviceStartupMode.remoteInitialization ||
      DeviceStartupMode.remoteInitialSetup ||
      DeviceStartupMode.localInitialSetup => DeviceInitializationPage(
        onInitialized: _reload,
      ),
      DeviceStartupMode.localLogin => const TimeClockPage(),
    };
  }

  Future<AppResult<DeviceStartupMode>> _startupMode() {
    return serviceLocator<DeviceInitializationService>().getStartupMode();
  }

  void _reload() {
    setState(() => _future = _startupMode());
  }
}
