import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const _rememberPosEmailKey = 'auth.remember_pos_email';
  static const _rememberedPosEmailKey = 'auth.remembered_pos_email';

  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _remoteAdminMode = false;
  bool _rememberPosEmail = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRememberedPosEmail());
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    _passwordController.dispose();
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
                      if (!widget.setupRequired) ...[
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: false,
                              icon: Icon(Icons.pin_outlined),
                              label: Text('POS / PIN'),
                            ),
                            ButtonSegment<bool>(
                              value: true,
                              icon: Icon(Icons.cloud_done_outlined),
                              label: Text('Admin remoto'),
                            ),
                          ],
                          selected: {_remoteAdminMode},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _remoteAdminMode = selection.first;
                              _localError = null;
                              _pinController.clear();
                              _passwordController.clear();
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (widget.setupRequired) ...[
                        AppInput(
                          label: l10n.displayNameField,
                          controller: _displayNameController,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (!widget.setupRequired && !_remoteAdminMode) ...[
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          title: const Text('Recordar correo'),
                          value: _rememberPosEmail,
                          onChanged: (value) {
                            final enabled = value ?? false;
                            setState(() => _rememberPosEmail = enabled);
                            if (!enabled) {
                              unawaited(_clearRememberedPosEmail());
                            }
                          },
                        ),
                        const SizedBox(height: 4),
                      ],
                      AppInput(
                        label: l10n.emailField,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      if (_remoteAdminMode && !widget.setupRequired)
                        AppInput(
                          label: 'Clave remota',
                          controller: _passwordController,
                          obscureText: true,
                        )
                      else
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
                            : _remoteAdminMode
                            ? Icons.cloud_done_outlined
                            : Icons.login,
                        label: widget.setupRequired
                            ? l10n.createInitialAdminAction
                            : _remoteAdminMode
                            ? 'Entrar como administrador'
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
    final password = _passwordController.text;

    final secretIsEmpty = _remoteAdminMode && !widget.setupRequired
        ? password.trim().isEmpty
        : pin.isEmpty;

    if (email.isEmpty ||
        secretIsEmpty ||
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

    if (_remoteAdminMode) {
      context.read<AuthBloc>().add(
        AuthRemoteAdminSignInRequested(email: email, password: password),
      );
      return;
    }

    context.read<AuthBloc>().add(
      AuthPinSignInRequested(email: email, pin: pin),
    );
    unawaited(_persistRememberedPosEmail(email));
  }

  Future<void> _loadRememberedPosEmail() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final shouldRemember = preferences.getBool(_rememberPosEmailKey) ?? false;
    final rememberedEmail = preferences.getString(_rememberedPosEmailKey);
    setState(() {
      _rememberPosEmail = shouldRemember;
      if (shouldRemember &&
          rememberedEmail != null &&
          rememberedEmail.trim().isNotEmpty &&
          _emailController.text.trim().isEmpty) {
        _emailController.text = rememberedEmail;
      }
    });
  }

  Future<void> _persistRememberedPosEmail(String email) async {
    final preferences = await SharedPreferences.getInstance();
    if (_rememberPosEmail) {
      await preferences.setBool(_rememberPosEmailKey, true);
      await preferences.setString(_rememberedPosEmailKey, email);
      return;
    }

    await preferences.setBool(_rememberPosEmailKey, false);
    await preferences.remove(_rememberedPosEmailKey);
  }

  Future<void> _clearRememberedPosEmail() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_rememberPosEmailKey, false);
    await preferences.remove(_rememberedPosEmailKey);
  }
}
