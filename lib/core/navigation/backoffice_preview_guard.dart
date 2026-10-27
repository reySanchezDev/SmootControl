import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_state.dart';
import 'package:smoo_control/features/auth/presentation/pages/login_page.dart';

/// Allows the read-only Backoffice V2 design preview for signed-in users.
///
/// The preview must never instantiate business pages or query production data.
/// It does not grant any permissions to operational routes.
class BackofficePreviewGuard extends StatelessWidget {
  /// Creates the preview-only authentication gate.
  const BackofficePreviewGuard({required this.child, super.key});

  /// Illustration-only view protected by the authentication state.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) => switch (state) {
        Authenticated() => child,
        _ => const LoginPage(),
      },
    );
  }
}
