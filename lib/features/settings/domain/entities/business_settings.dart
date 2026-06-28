import 'package:equatable/equatable.dart';

/// Business data used in receipts, PDFs, and invoice numbering.
final class BusinessSettings extends Equatable {
  /// Creates business settings.
  const BusinessSettings({
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

  /// Default settings used before the administrator saves real data.
  static const empty = BusinessSettings(
    businessName: '',
    showCompanyInfoOnReceipts: true,
    invoicePrefix: 'F',
    initialInvoiceNumber: 1,
    nextInvoiceNumber: 1,
  );

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

  /// Creates a copy with selected values changed.
  BusinessSettings copyWith({
    String? businessName,
    String? legalName,
    String? taxNumber,
    String? phone,
    String? address,
    bool? showCompanyInfoOnReceipts,
    String? invoicePrefix,
    int? initialInvoiceNumber,
    int? nextInvoiceNumber,
  }) {
    return BusinessSettings(
      businessName: businessName ?? this.businessName,
      legalName: legalName ?? this.legalName,
      taxNumber: taxNumber ?? this.taxNumber,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      showCompanyInfoOnReceipts:
          showCompanyInfoOnReceipts ?? this.showCompanyInfoOnReceipts,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      initialInvoiceNumber: initialInvoiceNumber ?? this.initialInvoiceNumber,
      nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
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
