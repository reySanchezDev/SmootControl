import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/payment_methods/domain/repositories/i_payment_methods_repository.dart';
import 'package:smoo_control/features/payment_methods/presentation/bloc/payment_methods_event.dart';
import 'package:smoo_control/features/payment_methods/presentation/bloc/payment_methods_state.dart';
import 'package:uuid/uuid.dart';

/// BLoC for payment methods management.
final class PaymentMethodsBloc
    extends Bloc<PaymentMethodsEvent, PaymentMethodsState> {
  /// Creates a payment methods BLoC.
  PaymentMethodsBloc({
    required IPaymentMethodsRepository repository,
    required IAuditLogRepository auditLogRepository,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _auditLogRepository = auditLogRepository,
       _uuid = uuid,
       super(const PaymentMethodsInitial()) {
    on<PaymentMethodsLoadRequested>(_onLoadRequested);
    on<PaymentMethodSaved>(_onPaymentMethodSaved);
    on<PaymentMethodRemoved>(_onPaymentMethodRemoved);
  }

  final IPaymentMethodsRepository _repository;
  final IAuditLogRepository _auditLogRepository;
  final Uuid _uuid;

  Future<void> _onLoadRequested(
    PaymentMethodsLoadRequested event,
    Emitter<PaymentMethodsState> emit,
  ) async {
    emit(const PaymentMethodsLoading());
    final result = await _repository.getPaymentMethods();
    emit(
      result.when(
        success: PaymentMethodsLoaded.new,
        failure: PaymentMethodsFailure.new,
      ),
    );
  }

  Future<void> _onPaymentMethodSaved(
    PaymentMethodSaved event,
    Emitter<PaymentMethodsState> emit,
  ) async {
    emit(const PaymentMethodsLoading());
    final saveResult = await _repository.savePaymentMethod(event.method);

    switch (saveResult) {
      case AppFailureResult(:final error):
        emit(PaymentMethodsFailure(error));
        return;
      case AppSuccess():
        break;
    }

    await _auditLogRepository.saveEntry(
      AuditLogEntry(
        id: _uuid.v4(),
        action: 'payment_methods.save',
        entityName: 'payment_methods',
        entityId: event.method.id,
        details: {
          'name': event.method.name,
          'parentId': event.method.parentId,
          'isPaymentTarget': event.method.isPaymentTarget,
          'requiresReference': event.method.requiresReference,
          'affectsCashRegister': event.method.affectsCashRegister,
          'isActive': event.method.isActive,
        },
        occurredAt: DateTime.now(),
      ),
    );

    final loadResult = await _repository.getPaymentMethods();
    emit(
      loadResult.when(
        success: PaymentMethodsLoaded.new,
        failure: PaymentMethodsFailure.new,
      ),
    );
  }

  Future<void> _onPaymentMethodRemoved(
    PaymentMethodRemoved event,
    Emitter<PaymentMethodsState> emit,
  ) async {
    emit(const PaymentMethodsLoading());
    final removeResult = await _repository.removePaymentMethodLevel(
      event.method,
    );

    if (removeResult case AppFailureResult(:final error)) {
      emit(PaymentMethodsFailure(error));
      return;
    }

    await _auditLogRepository.saveEntry(
      AuditLogEntry(
        id: _uuid.v4(),
        action: 'payment_methods.remove',
        entityName: 'payment_methods',
        entityId: event.method.id,
        details: {
          'name': event.method.name,
          'parentId': event.method.parentId,
          'isPaymentTarget': event.method.isPaymentTarget,
        },
        occurredAt: DateTime.now(),
      ),
    );

    final loadResult = await _repository.getPaymentMethods();
    emit(
      loadResult.when(
        success: PaymentMethodsLoaded.new,
        failure: PaymentMethodsFailure.new,
      ),
    );
  }
}
