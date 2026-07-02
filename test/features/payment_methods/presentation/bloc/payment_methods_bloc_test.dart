import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/payment_methods/domain/repositories/i_payment_methods_repository.dart';
import 'package:smoo_control/features/payment_methods/presentation/bloc/payment_methods_bloc.dart';
import 'package:smoo_control/features/payment_methods/presentation/bloc/payment_methods_event.dart';
import 'package:smoo_control/features/payment_methods/presentation/bloc/payment_methods_state.dart';

void main() {
  group('PaymentMethodsBloc', () {
    const method = PaymentMethod(
      id: 'payment-1',
      name: 'Efectivo',
      affectsCashRegister: true,
      requiresReference: false,
      isActive: true,
    );

    blocTest<PaymentMethodsBloc, PaymentMethodsState>(
      'loads payment methods',
      build: () => PaymentMethodsBloc(
        repository: _PaymentMethodsRepositoryFake(
          methodsResult: const AppSuccess([method]),
        ),
        auditLogRepository: _AuditLogRepositoryFake(),
      ),
      act: (bloc) => bloc.add(const PaymentMethodsLoadRequested()),
      expect: () => const [
        PaymentMethodsLoading(),
        PaymentMethodsLoaded([method]),
      ],
    );

    blocTest<PaymentMethodsBloc, PaymentMethodsState>(
      'emits failure when loading fails',
      build: () => PaymentMethodsBloc(
        repository: _PaymentMethodsRepositoryFake(
          methodsResult: const AppFailureResult(
            AppFailure(code: 'methods_error', message: 'Error'),
          ),
        ),
        auditLogRepository: _AuditLogRepositoryFake(),
      ),
      act: (bloc) => bloc.add(const PaymentMethodsLoadRequested()),
      expect: () => const [
        PaymentMethodsLoading(),
        PaymentMethodsFailure(
          AppFailure(code: 'methods_error', message: 'Error'),
        ),
      ],
    );

    late _AuditLogRepositoryFake auditRepository;

    blocTest<PaymentMethodsBloc, PaymentMethodsState>(
      'audits payment method save',
      build: () {
        auditRepository = _AuditLogRepositoryFake();

        return PaymentMethodsBloc(
          repository: _PaymentMethodsRepositoryFake(
            methodsResult: const AppSuccess([method]),
          ),
          auditLogRepository: auditRepository,
        );
      },
      act: (bloc) => bloc.add(const PaymentMethodSaved(method)),
      expect: () => const [
        PaymentMethodsLoading(),
        PaymentMethodsLoaded([method]),
      ],
      verify: (_) {
        expect(
          auditRepository.entries.single.action,
          'payment_methods.save',
        );
        expect(auditRepository.entries.single.entityId, method.id);
        expect(
          auditRepository.entries.single.details['requiresReference'],
          isFalse,
        );
      },
    );

    late _AuditLogRepositoryFake removeAuditRepository;

    blocTest<PaymentMethodsBloc, PaymentMethodsState>(
      'audits payment method level removal',
      build: () {
        removeAuditRepository = _AuditLogRepositoryFake();

        return PaymentMethodsBloc(
          repository: _PaymentMethodsRepositoryFake(
            methodsResult: const AppSuccess([method]),
          ),
          auditLogRepository: removeAuditRepository,
        );
      },
      act: (bloc) => bloc.add(const PaymentMethodRemoved(_childMethod)),
      expect: () => const [
        PaymentMethodsLoading(),
        PaymentMethodsLoaded([method]),
      ],
      verify: (_) {
        expect(
          removeAuditRepository.entries.single.action,
          'payment_methods.remove',
        );
        expect(removeAuditRepository.entries.single.entityId, _childMethod.id);
      },
    );

    late _AuditLogRepositoryFake rootRemoveAuditRepository;

    blocTest<PaymentMethodsBloc, PaymentMethodsState>(
      'removes a root leaf payment method',
      build: () {
        rootRemoveAuditRepository = _AuditLogRepositoryFake();

        return PaymentMethodsBloc(
          repository: _PaymentMethodsRepositoryFake(
            methodsResult: const AppSuccess(<PaymentMethod>[]),
          ),
          auditLogRepository: rootRemoveAuditRepository,
        );
      },
      act: (bloc) => bloc.add(const PaymentMethodRemoved(method)),
      expect: () => const [
        PaymentMethodsLoading(),
        PaymentMethodsLoaded(<PaymentMethod>[]),
      ],
      verify: (_) {
        expect(
          rootRemoveAuditRepository.entries.single.action,
          'payment_methods.remove',
        );
        expect(rootRemoveAuditRepository.entries.single.entityId, method.id);
      },
    );
  });
}

const _childMethod = PaymentMethod(
  id: 'payment-child',
  name: 'BANPRO',
  parentId: 'payment-1',
  affectsCashRegister: false,
  requiresReference: false,
  isPaymentTarget: false,
  isActive: true,
);

final class _PaymentMethodsRepositoryFake implements IPaymentMethodsRepository {
  _PaymentMethodsRepositoryFake({
    required this.methodsResult,
  });

  final AppResult<List<PaymentMethod>> methodsResult;

  @override
  Future<AppResult<List<PaymentMethod>>> getPaymentMethods() async {
    return methodsResult;
  }

  @override
  Future<AppResult<PaymentMethod>> savePaymentMethod(
    PaymentMethod method,
  ) async {
    return AppSuccess(method);
  }

  @override
  Future<AppResult<PaymentMethod>> removePaymentMethodLevel(
    PaymentMethod method,
  ) async {
    return AppSuccess(method);
  }
}

final class _AuditLogRepositoryFake implements IAuditLogRepository {
  final List<AuditLogEntry> entries = [];

  @override
  Future<AppResult<List<AuditLogEntry>>> getEntriesByDate(DateTime date) async {
    return AppSuccess(entries);
  }

  @override
  Future<AppResult<AuditLogEntry>> saveEntry(AuditLogEntry entry) async {
    entries.add(entry);
    return AppSuccess(entry);
  }
}
