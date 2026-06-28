import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';

/// Data model for business settings.
final class BusinessSettingsModel extends Equatable {
  /// Creates a business settings model.
  const BusinessSettingsModel({
    required this.businessName,
    required this.showCompanyInfoOnReceipts,
    required this.invoicePrefix,
    required this.initialInvoiceNumber,
    required this.nextInvoiceNumber,
    this.legalName,
    this.taxNumber,
    this.phone,
    this.address,
  });

  /// Creates a model from a local Drift row.
  factory BusinessSettingsModel.fromLocal(LocalBusinessSetting row) {
    return BusinessSettingsModel(
      businessName: row.businessName,
      legalName: row.legalName,
      taxNumber: row.taxNumber,
      phone: row.phone,
      address: row.address,
      showCompanyInfoOnReceipts: row.showCompanyInfoOnReceipts,
      invoicePrefix: row.invoicePrefix,
      initialInvoiceNumber: row.initialInvoiceNumber,
      nextInvoiceNumber: row.nextInvoiceNumber,
    );
  }

  /// Creates a model from a domain entity.
  factory BusinessSettingsModel.fromEntity(BusinessSettings entity) {
    return BusinessSettingsModel(
      businessName: entity.businessName,
      legalName: entity.legalName,
      taxNumber: entity.taxNumber,
      phone: entity.phone,
      address: entity.address,
      showCompanyInfoOnReceipts: entity.showCompanyInfoOnReceipts,
      invoicePrefix: entity.invoicePrefix,
      initialInvoiceNumber: entity.initialInvoiceNumber,
      nextInvoiceNumber: entity.nextInvoiceNumber,
    );
  }

  /// Public business name.
  final String businessName;

  /// Legal business name.
  final String? legalName;

  /// Tax identifier.
  final String? taxNumber;

  /// Business phone.
  final String? phone;

  /// Business address.
  final String? address;

  /// Whether company information appears in PDFs.
  final bool showCompanyInfoOnReceipts;

  /// Invoice prefix.
  final String invoicePrefix;

  /// First invoice number configured by the administrator.
  final int initialInvoiceNumber;

  /// Next invoice number assigned by the system.
  final int nextInvoiceNumber;

  /// Converts this model to a domain entity.
  BusinessSettings toEntity() {
    return BusinessSettings(
      businessName: businessName,
      legalName: legalName,
      taxNumber: taxNumber,
      phone: phone,
      address: address,
      showCompanyInfoOnReceipts: showCompanyInfoOnReceipts,
      invoicePrefix: invoicePrefix,
      initialInvoiceNumber: initialInvoiceNumber,
      nextInvoiceNumber: nextInvoiceNumber,
    );
  }

  @override
  List<Object?> get props => [
    businessName,
    legalName,
    taxNumber,
    phone,
    address,
    showCompanyInfoOnReceipts,
    invoicePrefix,
    initialInvoiceNumber,
    nextInvoiceNumber,
  ];
}
