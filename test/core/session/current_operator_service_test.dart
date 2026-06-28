import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';

void main() {
  group('CurrentOperatorService', () {
    test('returns the centralized local fallback user id', () {
      const service = CurrentOperatorService();

      expect(service.userId, CurrentOperatorService.localUserId);
    });
  });
}
