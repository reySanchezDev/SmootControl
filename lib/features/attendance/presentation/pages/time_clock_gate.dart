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
  const TimeClockGate({
    this.startupModeLoader,
    this.timeClockPageBuilder,
    this.initializationPageBuilder,
    super.key,
  });

  /// Optional test seam; production resolves the registered startup service.
  final Future<AppResult<DeviceStartupMode>> Function()? startupModeLoader;

  /// Optional test seam; production presents the actual marker page.
  final WidgetBuilder? timeClockPageBuilder;

  /// Optional test seam; production presents normal device initialization.
  final Widget Function(BuildContext, VoidCallback)? initializationPageBuilder;

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
      key: ValueKey(_future),
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
      DeviceStartupMode.localInitialSetup =>
        widget.initializationPageBuilder?.call(context, _reload) ??
            DeviceInitializationPage(onInitialized: _reload),
      DeviceStartupMode.localLogin =>
        widget.timeClockPageBuilder?.call(context) ?? const TimeClockPage(),
    };
  }

  Future<AppResult<DeviceStartupMode>> _startupMode() {
    return widget.startupModeLoader?.call() ??
        serviceLocator<DeviceInitializationService>().getStartupMode();
  }

  void _reload() {
    setState(() {
      _future = _startupMode();
    });
  }
}
