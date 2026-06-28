import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/pos/domain/entities/account_split_draft.dart';
import 'package:smoo_control/features/pos/domain/services/account_separation_service.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item_draft.dart';

void main() {
  group('AccountSeparationService', () {
    const service = AccountSeparationService();
    const items = [
      SaleItemDraft(
        id: 'item-1',
        productId: 'product-1',
        productName: 'Cafe',
        quantity: 1,
        unitPriceInCents: 250,
      ),
      SaleItemDraft(
        id: 'item-2',
        productId: 'product-2',
        productName: 'Sopa',
        quantity: 1,
        unitPriceInCents: 500,
      ),
    ];

    test('accepts accounts when every item is assigned once', () {
      final result = service.validate(
        tableItems: items,
        accounts: const [
          AccountSplitDraft(
            id: 'account-1',
            tableId: 'table-1',
            name: 'Ana',
            itemIds: ['item-1'],
          ),
          AccountSplitDraft(
            id: 'account-2',
            tableId: 'table-1',
            name: 'Luis',
            itemIds: ['item-2'],
          ),
        ],
      );

      expect(result, isA<AppSuccess<List<AccountSplitDraft>>>());
    });

    test('rejects when an item is pending', () {
      final result = service.validate(
        tableItems: items,
        accounts: const [
          AccountSplitDraft(
            id: 'account-1',
            tableId: 'table-1',
            name: 'Ana',
            itemIds: ['item-1'],
          ),
          AccountSplitDraft(
            id: 'account-2',
            tableId: 'table-1',
            name: 'Luis',
            itemIds: [],
          ),
        ],
      );

      final error = (result as AppFailureResult<List<AccountSplitDraft>>).error;

      expect(error.code, 'account_without_items');
    });

    test('rejects duplicated item assignment', () {
      final result = service.validate(
        tableItems: items,
        accounts: const [
          AccountSplitDraft(
            id: 'account-1',
            tableId: 'table-1',
            name: 'Ana',
            itemIds: ['item-1'],
          ),
          AccountSplitDraft(
            id: 'account-2',
            tableId: 'table-1',
            name: 'Luis',
            itemIds: ['item-1'],
          ),
        ],
      );

      final error = (result as AppFailureResult<List<AccountSplitDraft>>).error;

      expect(error.code, 'duplicated_items');
    });
  });
}
