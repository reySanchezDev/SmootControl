part of 'device_initialization_service.dart';

extension _DeviceInitializationLocalSupport on DeviceInitializationService {
  Future<bool> _hasLocalPinUser() async {
    final query = _database.select(_database.localUserProfiles)
      ..where((user) {
        return user.isActive.equals(true) &
            user.pinSalt.isNotNull() &
            user.pinHash.isNotNull();
      })
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  Future<void> _markInitialized({
    required RemoteBootstrapSession session,
    required CatalogPullSummary summary,
    String? deviceDisplayName,
  }) async {
    final now = DateTime.now();
    final deviceId = _uuid.v4();
    final deviceSecret = '${_uuid.v4()}${_uuid.v4()}';
    final registration = await _remoteAuthService.registerSyncDevice(
      session: session,
      deviceId: deviceId,
      deviceSecret: deviceSecret,
      deviceName: deviceDisplayName,
    );
    if (registration case AppFailureResult(:final error)) {
      throw StateError(error.message);
    }

    final state = LocalDeviceStateCompanion.insert(
      deviceId: deviceId,
      restaurantId: session.restaurantId,
      initializedByUserId: session.userId,
      initializedAt: now,
      lastFullRestoreAt: now,
      lastRestoreStatus: 'completed',
      lastRestoreError: const Value(null),
      syncDeviceId: Value(deviceId),
      syncDeviceSecret: Value(deviceSecret),
    );

    await _database.transaction(() async {
      await _database
          .into(_database.localDeviceState)
          .insert(state, mode: InsertMode.insertOrReplace);
      await _audit(
        action: 'device.initialize',
        actorUserId: session.userId,
        details: {
          'restaurantId': session.restaurantId,
          'recordsRestored': summary.total,
        },
      );
    });
  }

  Future<void> _markRestoreFailed({
    required RemoteBootstrapSession session,
    required String error,
  }) async {
    final now = DateTime.now();
    final existing = await (_database.select(
      _database.localDeviceState,
    )..where((row) => row.id.equals('default'))).getSingleOrNull();

    await _database.transaction(() async {
      await _database
          .into(_database.localDeviceState)
          .insert(
            LocalDeviceStateCompanion.insert(
              deviceId: existing?.deviceId ?? _uuid.v4(),
              restaurantId: session.restaurantId,
              initializedByUserId: session.userId,
              initializedAt: existing?.initializedAt ?? now,
              lastFullRestoreAt: now,
              lastRestoreStatus: 'failed',
              lastRestoreError: Value(error),
            ),
            mode: InsertMode.insertOrReplace,
          );
      await _audit(
        action: 'device.restore.failed',
        actorUserId: session.userId,
        details: {
          'restaurantId': session.restaurantId,
          'error': error,
        },
      );
    });
  }

  Future<void> _audit({
    required String action,
    required String actorUserId,
    required Map<String, Object?> details,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final detailsJson = jsonEncode(details);
    await _database
        .into(_database.localAuditLogs)
        .insert(
          LocalAuditLogsCompanion.insert(
            id: id,
            actorUserId: Value(actorUserId),
            action: action,
            entityType: 'device_state',
            entityId: const Value('default'),
            detailsJson: Value(detailsJson),
            occurredAt: now,
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
    await _database
        .into(_database.localSyncQueue)
        .insert(
          LocalSyncQueueCompanion.insert(
            id: _uuid.v4(),
            entityType: 'audit_logs',
            entityId: id,
            operation: 'create',
            payloadJson: jsonEncode({
              'id': id,
              'actorUserId': actorUserId,
              'action': action,
              'entityName': 'device_state',
              'entityId': 'default',
              'details': details,
              'occurredAt': now.toIso8601String(),
            }),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}
