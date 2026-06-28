import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/theme/app_palette.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Local login page for POS operators and administrators.
class LoginPage extends StatefulWidget {
  /// Creates the login page.
  const LoginPage({
    this.failure,
    this.setupRequired = false,
    super.key,
  });

  /// Failure message to show.
  final String? failure;

  /// Whether the first administrator must be created.
  final bool setupRequired;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final error = _localError ?? widget.failure;

    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  border: Border.all(color: AppPalette.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.point_of_sale_outlined,
                        color: colorScheme.primary,
                        size: 40,
                      ),
                      const SizedBox(height: 16),
                      AppText(
                        widget.setupRequired
                            ? l10n.initialAdminTitle
                            : l10n.loginTitle,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        variant: AppTextVariant.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      AppText(
                        widget.setupRequired
                            ? l10n.initialAdminMessage
                            : l10n.loginMessage,
                        maxLines: 3,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (widget.setupRequired) ...[
                        AppInput(
                          label: l10n.displayNameField,
                          controller: _displayNameController,
                        ),
                        const SizedBox(height: 12),
                      ],
                      AppInput(
                        label: l10n.emailField,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        label: l10n.pinField,
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        AppText(
                          error,
                          maxLines: 3,
                          textAlign: TextAlign.center,
                          variant: AppTextVariant.label,
                        ),
                      ],
                      const SizedBox(height: 24),
                      AppButton(
                        icon: widget.setupRequired
                            ? Icons.admin_panel_settings_outlined
                            : Icons.login,
                        label: widget.setupRequired
                            ? l10n.createInitialAdminAction
                            : l10n.loginAction,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();

    if (email.isEmpty ||
        pin.isEmpty ||
        (widget.setupRequired && displayName.isEmpty)) {
      setState(() => _localError = l10n.fieldRequiredError);
      return;
    }

    setState(() => _localError = null);

    if (widget.setupRequired) {
      context.read<AuthBloc>().add(
        AuthInitialAdminCreated(
          displayName: displayName,
          email: email,
          pin: pin,
        ),
      );
      return;
    }

    context.read<AuthBloc>().add(
      AuthPinSignInRequested(email: email, pin: pin),
    );
  }
}
