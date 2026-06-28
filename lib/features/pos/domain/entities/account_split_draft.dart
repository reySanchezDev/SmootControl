import 'package:equatable/equatable.dart';

/// Draft account used when a table is split into named invoices.
final class AccountSplitDraft extends Equatable {
  /// Creates an account split draft.
  const AccountSplitDraft({
    required this.id,
    required this.tableId,
    required this.name,
    required this.itemIds,
    this.paymentMethodId,
    this.paymentReference,
  });

  /// Unique account draft identifier.
  final String id;

  /// Original table identifier.
  final String tableId;

  /// Visible invoice/account name.
  final String name;

  /// Draft sale item identifiers assigned to this account.
  final List<String> itemIds;

  /// Payment method selected when accounts are paid separately.
  final String? paymentMethodId;

  /// Optional payment reference for this account.
  final String? paymentReference;

  /// Creates a modified copy.
  AccountSplitDraft copyWith({
    String? name,
    List<String>? itemIds,
    String? paymentMethodId,
    String? paymentReference,
    bool clearPaymentReference = false,
  }) {
    return AccountSplitDraft(
      id: id,
      tableId: tableId,
      name: name ?? this.name,
      itemIds: itemIds ?? this.itemIds,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      paymentReference: clearPaymentReference
          ? null
          : paymentReference ?? this.paymentReference,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tableId,
    name,
    itemIds,
    paymentMethodId,
    paymentReference,
  ];
}
