import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/payment_methods/data/datasources/local_payment_methods_datasource.dart';
import 'package:smoo_control/features/payment_methods/data/models/payment_method_model.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/payment_methods/domain/repositories/i_payment_methods_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

/// Payment methods repository backed by the local offline database.
final class PaymentMethodsRepository implements IPaymentMethodsRepository {
  /// Creates a payment methods repository.
  const PaymentMethodsRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
    ISyncRemoteSender? remoteSender,
  }) : _syncQueueRepository = syncQueueRepository,
       _remoteSender = remoteSender;

  final LocalPaymentMethodsDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;
  final ISyncRemoteSender? _remoteSender;

  @override
  Future<AppResult<List<PaymentMethod>>> getPaymentMethods() async {
    try {
      final methods = await _localDataSource.getPaymentMethods();
      return AppSuccess(methods.map((method) => method.toEntity()).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'payment_methods_read_failed',
          message: 'No se pudieron leer los metodos de pago locales.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<PaymentMethod>> savePaymentMethod(
    PaymentMethod method,
  ) async {
    try {
      final model = PaymentMethodModel.fromEntity(method);
      await _pushPaymentMethodRemote(method);
      final saved = await _localDataSource.savePaymentMethod(model);
      final entity = saved.toEntity();
      if (_remoteSender == null) {
        await _enqueuePaymentMethod(entity);
      }

      return AppSuccess(entity);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'payment_method_save_failed',
          message: 'No se pudo guardar el metodo de pago local.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<PaymentMethod>> removePaymentMethodLevel(
    PaymentMethod method,
  ) async {
    final parentId = method.parentId;
    if (parentId == null) {
      return const AppFailureResult(
        AppFailure(
          code: 'payment_root_remove_blocked',
          message: 'No se puede quitar un metodo de pago principal.',
        ),
      );
    }

    try {
      if (_remoteSender != null) {
        await _pushRemovedPaymentMethodRemote(method);
      }
      await _localDataSource.removePaymentMethodLevel(
        methodId: method.id,
        parentId: parentId,
      );
      if (_remoteSender == null) {
        await _enqueueRemovedPaymentMethod(method);
      }

      return AppSuccess(method);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'payment_method_remove_failed',
          message: 'No se pudo quitar el nivel de pago local.',
          cause: error,
        ),
      );
    }
  }

  Future<void> _enqueuePaymentMethod(PaymentMethod method) async {
    await _syncQueueRepository?.enqueue(
      entityType: 'payment_methods',
      entityId: method.id,
      operation: SyncOperation.create,
      payload: {
        'id': method.id,
        'name': method.name,
        'parentId': method.parentId,
        'groupName': method.groupName,
        'currencyCode': method.currencyCode,
        'displayOrder': method.displayOrder,
        'isPaymentTarget': method.isPaymentTarget,
        'affectsCashRegister': method.affectsCashRegister,
        'requiresReference': method.requiresReference,
        'isActive': method.isActive,
      },
    );
  }

  Future<void> _pushPaymentMethodRemote(PaymentMethod method) async {
    final remoteSender = _remoteSender;
    if (remoteSender == null) return;

    final now = DateTime.now();
    await remoteSender.push(
      SyncQueueItem(
        id: 'admin-direct-payment_methods-${method.id}',
        entityType: 'payment_methods',
        entityId: method.id,
        operation: SyncOperation.create,
        payload: _paymentMethodPayload(method),
        status: SyncQueueStatus.pending,
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _enqueueRemovedPaymentMethod(PaymentMethod method) async {
    await _syncQueueRepository?.enqueue(
      entityType: 'payment_methods',
      entityId: method.id,
      operation: SyncOperation.delete,
      payload: {
        'id': method.id,
        'name': method.name,
        'parentId': method.parentId,
      },
    );
  }

  Future<void> _pushRemovedPaymentMethodRemote(PaymentMethod method) async {
    final remoteSender = _remoteSender;
    if (remoteSender == null) return;

    final now = DateTime.now();
    await remoteSender.push(
      SyncQueueItem(
        id: 'admin-direct-payment_methods-delete-${method.id}',
        entityType: 'payment_methods',
        entityId: method.id,
        operation: SyncOperation.delete,
        payload: {
          'id': method.id,
          'name': method.name,
          'parentId': method.parentId,
        },
        status: SyncQueueStatus.pending,
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Map<String, Object?> _paymentMethodPayload(PaymentMethod method) {
    return {
      'id': method.id,
      'name': method.name,
      'parentId': method.parentId,
      'groupName': method.groupName,
      'currencyCode': method.currencyCode,
      'displayOrder': method.displayOrder,
      'isPaymentTarget': method.isPaymentTarget,
      'affectsCashRegister': method.affectsCashRegister,
      'requiresReference': method.requiresReference,
      'isActive': method.isActive,
    };
  }
}
