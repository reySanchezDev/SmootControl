import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/theme/app_palette.dart';
import 'package:smoo_control/features/auth/domain/services/device_initialization_service.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';

/// Creates the first remote administrator for a clean Supabase tenant.
class RemoteInitialAdminSetupPage extends StatefulWidget {
  /// Creates the remote initial setup page.
  const RemoteInitialAdminSetupPage({super.key});

  @override
  State<RemoteInitialAdminSetupPage> createState() =>
      _RemoteInitialAdminSetupPageState();
}

class _RemoteInitialAdminSetupPageState
    extends State<RemoteInitialAdminSetupPage> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmationController = TextEditingController();
  final DeviceInitializationService _service =
      serviceLocator<DeviceInitializationService>();

  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    _pinConfirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
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
                        Icons.admin_panel_settings_outlined,
                        color: colorScheme.primary,
                        size: 42,
                      ),
                      const SizedBox(height: 16),
                      const AppText(
                        'Crear administrador remoto',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        variant: AppTextVariant.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const AppText(
                        'Supabase esta limpio. Crea el propietario inicial '
                        'y descarga la base operativa al dispositivo.',
                        maxLines: 4,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      AppInput(
                        label: 'Nombre visible',
                        controller: _displayNameController,
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        label: 'Correo administrador',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        label: 'Clave remota',
                        controller: _passwordController,
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        label: 'PIN local',
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        label: 'Confirmar PIN',
                        controller: _pinConfirmationController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        AppText(
                          _error!,
                          maxLines: 4,
                          textAlign: TextAlign.center,
                          variant: AppTextVariant.label,
                        ),
                      ],
                      const SizedBox(height: 24),
                      AppButton(
                        icon: Icons.cloud_done_outlined,
                        label: _busy
                            ? 'Creando administrador...'
                            : 'Crear administrador remoto',
                        onPressed: _busy ? null : _submit,
                      ),
                      if (_busy) ...[
                        const SizedBox(height: 16),
                        const Center(child: CircularProgressIndicator()),
                      ],
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

  Future<void> _submit() async {
    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final pin = _pinController.text.trim();
    final confirmation = _pinConfirmationController.text.trim();

    if (displayName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        pin.isEmpty ||
        confirmation.isEmpty) {
      setState(() => _error = 'Todos los campos son requeridos.');
      return;
    }
    if (password.length < 6) {
      setState(
        () => _error = 'La clave remota debe tener al menos 6 caracteres.',
      );
      return;
    }
    if (pin != confirmation) {
      setState(() => _error = 'El PIN y la confirmacion no coinciden.');
      return;
    }
    if (pin.length < 4) {
      setState(() => _error = 'El PIN debe tener al menos 4 digitos.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _service.createFirstRemoteAdminAndRestore(
      displayName: displayName,
      email: email,
      password: password,
      pin: pin,
    );
    if (!mounted) return;

    switch (result) {
      case AppFailureResult(:final error):
        setState(() {
          _busy = false;
          _error = error.message;
        });
      case AppSuccess():
        setState(() => _busy = false);
        await showAppMessageDialog(
          context: context,
          title: 'Dispositivo listo',
          message:
              'Administrador creado correctamente. Los datos operativos '
              'del POS fueron descargados para uso offline. El sistema '
              'administrativo seguira trabajando contra Supabase.',
        );
        if (!mounted) return;
        context.read<AuthBloc>().add(const AuthSessionRequested());
    }
  }
}
