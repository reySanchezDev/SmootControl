import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';
import 'package:smoo_control/features/sales/presentation/bloc/sales_event.dart';
import 'package:smoo_control/features/sales/presentation/bloc/sales_state.dart';
import 'package:uuid/uuid.dart';

/// BLoC for sales, sale details and voids.
final class SalesBloc extends Bloc<SalesEvent, SalesState> {
  /// Creates a sales BLoC.
  SalesBloc({
    required ISalesRepository repository,
    required IAuditLogRepository auditLogRepository,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _auditLogRepository = auditLogRepository,
       _uuid = uuid,
       super(const SalesInitial()) {
    on<SalesLoadRequested>(_onSalesLoadRequested);
    on<SaleItemsLoadRequested>(_onSaleItemsLoadRequested);
    on<SaleSaved>(_onSaleSaved);
    on<SaleVoided>(_onSaleVoided);
  }

  final ISalesRepository _repository;
  final IAuditLogRepository _auditLogRepository;
  final Uuid _uuid;

  Future<void> _onSalesLoadRequested(
    SalesLoadRequested event,
    Emitter<SalesState> emit,
  ) async {
    emit(const SalesLoading());
    final result = await _repository.getSales(from: event.from, to: event.to);
    emit(
      result.when(
        success: SalesLoaded.new,
        failure: SalesFailure.new,
      ),
    );
  }

  Future<void> _onSaleItemsLoadRequested(
    SaleItemsLoadRequested event,
    Emitter<SalesState> emit,
  ) async {
    emit(const SalesLoading());
    final result = await _repository.getSaleItems(event.saleId);
    emit(
      result.when(
        success: (items) => SaleItemsLoaded(
          saleId: event.saleId,
          items: items,
        ),
        failure: SalesFailure.new,
      ),
    );
  }

  Future<void> _onSaleSaved(
    SaleSaved event,
    Emitter<SalesState> emit,
  ) async {
    emit(const SalesLoading());
    final result = await _repository.saveSale(
      sale: event.sale,
      items: event.items,
    );
    emit(
      result.when(
        success: SaleSaveSuccess.new,
        failure: SalesFailure.new,
      ),
    );
  }

  Future<void> _onSaleVoided(
    SaleVoided event,
    Emitter<SalesState> emit,
  ) async {
    emit(const SalesLoading());
    final result = await _repository.voidSale(
      saleId: event.saleId,
      reason: event.reason,
      voidedBy: event.voidedBy,
    );
    emit(
      await result.when(
        success: (sale) async {
          await _auditLogRepository.saveEntry(
            AuditLogEntry(
              id: _uuid.v4(),
              actorUserId: event.voidedBy,
              action: 'sales.void',
              entityName: 'sales',
              entityId: event.saleId,
              details: {'reason': event.reason},
              occurredAt: DateTime.now(),
            ),
          );
          return SaleVoidSuccess(sale);
        },
        failure: SalesFailure.new,
      ),
    );
  }
}
