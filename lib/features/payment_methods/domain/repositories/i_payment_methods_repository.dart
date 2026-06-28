import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';

/// Contract for payment method persistence.
abstract interface class IPaymentMethodsRepository {
  /// Returns configured payment methods.
  Future<AppResult<List<PaymentMethod>>> getPaymentMethods();

  /// Saves a payment method.
  Future<AppResult<PaymentMethod>> savePaymentMethod(PaymentMethod method);

  /// Removes a nested payment level and moves direct children to its parent.
  Future<AppResult<PaymentMethod>> removePaymentMethodLevel(
    PaymentMethod method,
  );
}
