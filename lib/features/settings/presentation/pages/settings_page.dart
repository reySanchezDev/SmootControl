import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';
import 'package:smoo_control/features/settings/presentation/bloc/business_settings_bloc.dart';
import 'package:smoo_control/features/settings/presentation/bloc/business_settings_event.dart';
import 'package:smoo_control/features/settings/presentation/bloc/business_settings_state.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Business settings page.
class SettingsPage extends StatelessWidget {
  /// Creates the settings page.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider(
      create: (_) =>
          serviceLocator<BusinessSettingsBloc>()
            ..add(const BusinessSettingsLoadRequested()),
      child: AppPageScaffold(
        title: l10n.moduleSettings,
        body: const _SettingsBody(),
      ),
    );
  }
}

class _SettingsBody extends StatefulWidget {
  const _SettingsBody();

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  final _businessNameController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _invoicePrefixController = TextEditingController(text: 'F');
  final _initialNumberController = TextEditingController(text: '1');

  BusinessSettings? _currentSettings;
  bool _showCompanyInfoOnReceipts = true;
  bool _hasInitialized = false;
  String? _error;

  @override
  void dispose() {
    _businessNameController.dispose();
    _legalNameController.dispose();
    _taxNumberController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _invoicePrefixController.dispose();
    _initialNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocConsumer<BusinessSettingsBloc, BusinessSettingsState>(
      listener: (context, state) {
        if (state case BusinessSettingsLoaded(:final settings)) {
          if (!_hasInitialized || state.saved) {
            _applySettings(settings);
          }

          if (state.saved) {
            unawaited(
              showAppMessageDialog(
                context: context,
                message: l10n.settingsSavedMessage,
                title: l10n.moduleSettings,
              ),
            );
          }
        }
      },
      builder: (context, state) {
        return switch (state) {
          BusinessSettingsInitial() || BusinessSettingsLoading()
              when !_hasInitialized =>
            const AppLoadingPage(),
          BusinessSettingsFailure(:final failure) => AppEmptyState(
            icon: Icons.error_outline,
            message: failure.message,
            title: l10n.moduleSettings,
          ),
          _ => _SettingsForm(
            addressController: _addressController,
            businessNameController: _businessNameController,
            error: _error,
            initialNumberController: _initialNumberController,
            invoicePrefixController: _invoicePrefixController,
            legalNameController: _legalNameController,
            phoneController: _phoneController,
            showCompanyInfoOnReceipts: _showCompanyInfoOnReceipts,
            taxNumberController: _taxNumberController,
            onSave: _saveSettings,
            onShowCompanyInfoChanged: (value) {
              setState(() => _showCompanyInfoOnReceipts = value);
            },
          ),
        };
      },
    );
  }

  void _applySettings(BusinessSettings settings) {
    _businessNameController.text = settings.businessName;
    _legalNameController.text = settings.legalName ?? '';
    _taxNumberController.text = settings.taxNumber ?? '';
    _phoneController.text = settings.phone ?? '';
    _addressController.text = settings.address ?? '';
    _invoicePrefixController.text = settings.invoicePrefix;
    _initialNumberController.text = settings.initialInvoiceNumber.toString();

    setState(() {
      _currentSettings = settings;
      _error = null;
      _hasInitialized = true;
      _showCompanyInfoOnReceipts = settings.showCompanyInfoOnReceipts;
    });
  }

  void _saveSettings() {
    final l10n = AppLocalizations.of(context);
    final businessName = _businessNameController.text.trim();
    final invoicePrefix = _invoicePrefixController.text.trim().toUpperCase();
    final initialNumber = int.tryParse(_initialNumberController.text.trim());

    if (businessName.isEmpty || invoicePrefix.isEmpty) {
      setState(() => _error = l10n.fieldRequiredError);
      return;
    }

    if (initialNumber == null || initialNumber < 1) {
      setState(() => _error = l10n.numericFieldError);
      return;
    }

    setState(() => _error = null);
    context.read<BusinessSettingsBloc>().add(
      BusinessSettingsSaved(
        BusinessSettings(
          businessName: businessName,
          legalName: _optionalText(_legalNameController),
          taxNumber: _optionalText(_taxNumberController),
          phone: _optionalText(_phoneController),
          address: _optionalText(_addressController),
          showCompanyInfoOnReceipts: _showCompanyInfoOnReceipts,
          invoicePrefix: invoicePrefix,
          initialInvoiceNumber: initialNumber,
          nextInvoiceNumber: _nextInvoiceNumberFor(initialNumber),
        ),
      ),
    );
  }

  String? _optionalText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  int _nextInvoiceNumberFor(int initialNumber) {
    final currentNextNumber =
        _currentSettings?.nextInvoiceNumber ?? initialNumber;

    return currentNextNumber < initialNumber
        ? initialNumber
        : currentNextNumber;
  }
}

class _SettingsForm extends StatelessWidget {
  const _SettingsForm({
    required this.addressController,
    required this.businessNameController,
    required this.initialNumberController,
    required this.invoicePrefixController,
    required this.legalNameController,
    required this.onSave,
    required this.onShowCompanyInfoChanged,
    required this.phoneController,
    required this.showCompanyInfoOnReceipts,
    required this.taxNumberController,
    this.error,
  });

  final TextEditingController addressController;
  final TextEditingController businessNameController;
  final String? error;
  final TextEditingController initialNumberController;
  final TextEditingController invoicePrefixController;
  final TextEditingController legalNameController;
  final VoidCallback onSave;
  final ValueChanged<bool> onShowCompanyInfoChanged;
  final TextEditingController phoneController;
  final bool showCompanyInfoOnReceipts;
  final TextEditingController taxNumberController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(
                l10n.businessSettingsTitle,
                variant: AppTextVariant.titleMedium,
              ),
              const SizedBox(height: 16),
              AppInput(
                controller: businessNameController,
                label: l10n.businessNameField,
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: legalNameController,
                label: l10n.legalNameField,
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: taxNumberController,
                label: l10n.taxNumberField,
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                label: l10n.phoneField,
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: addressController,
                label: l10n.addressField,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: AppText(l10n.showCompanyInfoOnPdfField),
                value: showCompanyInfoOnReceipts,
                onChanged: (value) {
                  onShowCompanyInfoChanged(value ?? true);
                },
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: invoicePrefixController,
                label: l10n.invoicePrefixField,
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: initialNumberController,
                keyboardType: TextInputType.number,
                label: l10n.initialInvoiceNumberField,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                AppText(error!, maxLines: 2),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  icon: Icons.save_outlined,
                  label: l10n.saveAction,
                  onPressed: onSave,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
