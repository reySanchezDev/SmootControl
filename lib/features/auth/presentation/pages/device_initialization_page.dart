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
import 'package:smoo_control/features/auth/domain/services/remote_bootstrap_session.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';

/// Secure bootstrap page for clean tablets connected to Supabase.
class DeviceInitializationPage extends StatefulWidget {
  /// Creates the device initialization page.
  const DeviceInitializationPage({super.key});

  @override
  State<DeviceInitializationPage> createState() =>
      _DeviceInitializationPageState();
}

class _DeviceInitializationPageState extends State<DeviceInitializationPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmationController = TextEditingController();
  final DeviceInitializationService _service =
      serviceLocator<DeviceInitializationService>();

  RemoteBootstrapSession? _session;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    _pinConfirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final needsPin = _session != null && !_session!.hasLocalPin;

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
                        Icons.cloud_sync_outlined,
                        color: colorScheme.primary,
                        size: 42,
                      ),
                      const SizedBox(height: 16),
                      const AppText(
                        'Inicializar dispositivo',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        variant: AppTextVariant.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      AppText(
                        needsPin
                            ? 'Crea el PIN local para que este usuario pueda '
                                  'entrar offline despues de restaurar.'
                            : 'Ingresa con un administrador remoto para '
                                  'descargar la informacion de Supabase.',
                        maxLines: 4,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (!needsPin) ...[
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
                      ] else ...[
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
                      ],
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
                        icon: needsPin
                            ? Icons.pin_outlined
                            : Icons.admin_panel_settings_outlined,
                        label: _busy
                            ? (needsPin
                                  ? 'Guardando PIN...'
                                  : 'Validando administrador...')
                            : needsPin
                            ? 'Guardar PIN y restaurar'
                            : 'Validar administrador',
                        onPressed: _busy
                            ? null
                            : needsPin
                            ? _configurePinAndRestore
                            : _signInAndRestore,
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

  Future<void> _signInAndRestore() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Correo y clave remota son requeridos.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _service.signInRemoteAdmin(
      email: email,
      password: password,
    );
    if (!mounted) return;

    switch (result) {
      case AppFailureResult(:final error):
        setState(() {
          _busy = false;
          _error = error.message;
        });
      case AppSuccess(:final value):
        if (!value.hasLocalPin) {
          setState(() {
            _session = value;
            _busy = false;
          });
          return;
        }
        await _restore(value);
    }
  }

  Future<void> _configurePinAndRestore() async {
    final pin = _pinController.text.trim();
    final confirmation = _pinConfirmationController.text.trim();
    if (pin.isEmpty || confirmation.isEmpty) {
      setState(() => _error = 'PIN y confirmacion son requeridos.');
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

    final session = _session;
    if (session == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _service.configureRemotePin(
      session: session,
      pin: pin,
    );
    if (!mounted) return;

    switch (result) {
      case AppFailureResult(:final error):
        setState(() {
          _busy = false;
          _error = error.message;
        });
      case AppSuccess(:final value):
        await _restore(value);
    }
  }

  Future<void> _restore(RemoteBootstrapSession session) async {
    final result = await _service.restoreDevice(session: session);
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
              'Dispositivo inicializado correctamente. Los datos operativos '
              'del POS fueron descargados para uso offline. El sistema '
              'administrativo seguira trabajando contra Supabase.',
        );
        if (!mounted) return;
        context.read<AuthBloc>().add(const AuthSessionRequested());
    }
  }
}
