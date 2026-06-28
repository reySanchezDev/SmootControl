import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/auth/data/repositories/disabled_auth_repository.dart';
import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';

void main() {
  group('DisabledAuthRepository', () {
    const repository = DisabledAuthRepository();

    test('returns no current session', () async {
      final result = await repository.getCurrentSession();

      expect((result as AppSuccess<AuthSession?>).value, isNull);
    });

    test('fails Google sign-in explicitly', () async {
      final result = await repository.signInWithGoogle();

      expect(result, isA<AppFailureResult<AuthSession>>());
      expect(
        (result as AppFailureResult<AuthSession>).error.code,
        'auth_not_configured',
      );
    });
  });
}
