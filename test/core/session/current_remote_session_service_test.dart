import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';

void main() {
  test('expires and notifies listeners when token is too close to expiry', () {
    final service = CurrentRemoteSessionService()
      ..set(
        accessToken: 'token',
        userId: 'admin',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      );
    addTearDown(service.dispose);

    expect(service.onExpired, emits(null));

    expect(service.accessToken, isNull);
    expect(service.userId, isNull);
  });

  test('manual expiration clears the remote administrator session', () {
    final service = CurrentRemoteSessionService()
      ..set(
        accessToken: 'token',
        userId: 'admin',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
    addTearDown(service.dispose);

    service.expire();

    expect(service.accessToken, isNull);
    expect(service.userId, isNull);
  });
}
