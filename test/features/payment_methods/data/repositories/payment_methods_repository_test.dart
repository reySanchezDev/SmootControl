import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/payment_methods/data/datasources/local_payment_methods_datasource.dart';
import 'package:smoo_control/features/payment_methods/data/repositories/payment_methods_repository.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

void main() {
  group('PaymentMethodsRepository', () {
    late AppDatabase database;
    late PaymentMethodsRepository repository;
    late SyncQueueRepository syncQueueRepository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      syncQueueRepository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
      );
      repository = PaymentMethodsRepository(
        LocalPaymentMethodsDataSource(database),
        syncQueueRepository: syncQueueRepository,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('saves and returns local payment methods', () async {
      const method = PaymentMethod(
        id: 'payment-1',
        name: 'Transferencia',
        affectsCashRegister: false,
        requiresReference: true,
        isActive: true,
      );

      final saveResult = await repository.savePaymentMethod(method);
      final readResult = await repository.getPaymentMethods();
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(saveResult, isA<AppSuccess<PaymentMethod>>());
      expect(
        (readResult as AppSuccess<List<PaymentMethod>>).value.single,
        method,
      );
      final syncItem =
          (syncResult as AppSuccess<List<SyncQueueItem>>).value.single;
      expect(syncItem.entityType, 'payment_methods');
      expect(syncItem.entityId, method.id);
      expect(syncItem.payload['requiresReference'], isTrue);
    });

    test('removes a payment level and moves children to parent', () async {
      const root = PaymentMethod(
        id: 'transfer-root',
        name: 'Transferencias',
        affectsCashRegister: false,
        requiresReference: false,
        isPaymentTarget: false,
        isActive: true,
      );
      const bank = PaymentMethod(
        id: 'banpro',
        name: 'BANPRO',
        parentId: 'transfer-root',
        affectsCashRegister: false,
        requiresReference: false,
        isPaymentTarget: false,
        isActive: true,
      );
      const account = PaymentMethod(
        id: 'account',
        name: 'Cuenta 7888889',
        parentId: 'banpro',
        affectsCashRegister: false,
        requiresReference: true,
        isActive: true,
      );

      await repository.savePaymentMethod(root);
      await repository.savePaymentMethod(bank);
      await repository.savePaymentMethod(account);

      final removeResult = await repository.removePaymentMethodLevel(bank);
      final readResult = await repository.getPaymentMethods();
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(removeResult, isA<AppSuccess<PaymentMethod>>());
      final methods = (readResult as AppSuccess<List<PaymentMethod>>).value;
      expect(methods.any((method) => method.id == 'banpro'), isFalse);
      expect(
        methods.singleWhere((method) => method.id == 'account').parentId,
        'transfer-root',
      );
      final syncItems = (syncResult as AppSuccess<List<SyncQueueItem>>).value;
      expect(
        syncItems.any((item) {
          return item.entityId == 'banpro' &&
              item.operation == SyncOperation.delete;
        }),
        isTrue,
      );
    });

    test('does not remove local method when remote delete fails', () async {
      const root = PaymentMethod(
        id: 'transfer-root',
        name: 'Transferencias',
        affectsCashRegister: false,
        requiresReference: false,
        isPaymentTarget: false,
        isActive: true,
      );
      const bank = PaymentMethod(
        id: 'banpro',
        name: 'BANPRO',
        parentId: 'transfer-root',
        affectsCashRegister: false,
        requiresReference: false,
        isPaymentTarget: false,
        isActive: true,
      );
      final remoteFirstRepository = PaymentMethodsRepository(
        LocalPaymentMethodsDataSource(database),
        syncQueueRepository: syncQueueRepository,
        remoteSender: const _FailingRemoteSender(),
      );

      await repository.savePaymentMethod(root);
      await repository.savePaymentMethod(bank);

      final removeResult = await remoteFirstRepository.removePaymentMethodLevel(
        bank,
      );
      final readResult = await repository.getPaymentMethods();

      expect(removeResult, isA<AppFailureResult<PaymentMethod>>());
      final methods = (readResult as AppSuccess<List<PaymentMethod>>).value;
      expect(methods.any((method) => method.id == 'banpro'), isTrue);
    });
  });
}

final class _FailingRemoteSender implements ISyncRemoteSender {
  const _FailingRemoteSender();

  @override
  Future<void> push(SyncQueueItem item) {
    throw StateError('remote failed');
  }
}
