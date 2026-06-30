import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';

/// Blocks administrative modules when the device has no network connection.
class AdminOnlineGuard extends StatelessWidget {
  /// Creates an administrative connectivity guard.
  const AdminOnlineGuard({required this.child, super.key});

  /// Page shown when network is available.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConnectivityResult>>(
      future: Connectivity().checkConnectivity(),
      builder: (context, snapshot) {
        final results = snapshot.data;
        if (results == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final hasConnection = results.any(
          (result) => result != ConnectivityResult.none,
        );
        if (hasConnection) return child;

        return const Scaffold(
          body: AppEmptyState(
            icon: Icons.cloud_off_outlined,
            message: 'Se requiere conexion para administrar.',
            title: 'Sin conexion',
          ),
        );
      },
    );
  }
}
