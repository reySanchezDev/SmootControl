part of 'pilot_operation_reset_service.dart';

/// POS device shown in the controlled test-data cleanup utility.
final class PosDeviceCleanupCandidate {
  /// Creates a POS device cleanup candidate.
  const PosDeviceCleanupCandidate({
    required this.id,
    required this.name,
    required this.isCurrentDevice,
    required this.totalRows,
    this.lastActivityAt,
  });

  /// Remote POS device id.
  final String id;

  /// Human-friendly POS device name.
  final String name;

  /// Whether this remote device matches the local initialized POS.
  final bool isCurrentDevice;

  /// Rows currently linked to this POS device.
  final int totalRows;

  /// Last known operational activity.
  final DateTime? lastActivityAt;
}

/// Remote cleanup operations scoped to one initialized POS device.
extension PilotOperationResetDeviceCleanup on PilotOperationResetService {
  /// Lists initialized POS devices with remote operational row counts.
  Future<AppResult<List<PosDeviceCleanupCandidate>>>
  listDevicesForCleanup() async {
    try {
      final currentDeviceId = await _currentDeviceId();
      final decoded = await _postRpc(
        rpcName: 'app_list_pos_devices_for_cleanup',
        body: {'p_restaurant_id': _restaurantService.restaurantId},
      );
      if (decoded is! List) return const AppSuccess([]);
      return AppSuccess([
        for (final item in decoded.whereType<Map<String, Object?>>())
          PosDeviceCleanupCandidate(
            id: item['id']?.toString() ?? '',
            name: item['name']?.toString() ?? 'POS sin nombre',
            isCurrentDevice: item['id']?.toString() == currentDeviceId,
            totalRows:
                _int(item['sales_count']) +
                _int(item['staff_consumptions_count']) +
                _int(item['expenses_count']) +
                _int(item['salary_advances_count']) +
                _int(item['cash_sessions_count']) +
                _int(item['inventory_movements_count']) +
                _int(item['packaging_movements_count']) +
                _int(item['attendance_count']) +
                _int(item['overtime_candidates_count']),
            lastActivityAt: DateTime.tryParse(
              item['last_activity_at']?.toString() ?? '',
            ),
          ),
      ]);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'pos_device_cleanup_list_failed',
          message: 'No se pudieron leer los dispositivos POS.',
          cause: error,
        ),
      );
    }
  }

  Future<String?> _currentDeviceId() async {
    final state = await (_database.select(
      _database.localDeviceState,
    )..where((row) => row.id.equals('default'))).getSingleOrNull();
    return state?.syncDeviceId ?? state?.deviceId;
  }

  /// Cleans remote operational rows linked to one POS device.
  Future<AppResult<PilotOperationResetSummary>> cleanupDeviceTestData({
    required String confirmation,
    required String deviceId,
  }) async {
    try {
      if (confirmation.trim() != 'BORRAR DISPOSITIVO') {
        return const AppFailureResult(
          AppFailure(
            code: 'invalid_pos_device_cleanup_confirmation',
            message: 'Debes escribir exactamente BORRAR DISPOSITIVO.',
          ),
        );
      }
      final decoded = await _postRpc(
        rpcName: 'app_cleanup_pos_device_test_data',
        body: {
          'p_restaurant_id': _restaurantService.restaurantId,
          'p_device_id': deviceId,
          'p_confirmation': confirmation.trim(),
        },
      );
      final remoteRows = decoded is Map<String, Object?>
          ? _int(decoded['total_rows'])
          : 0;
      return AppSuccess(
        PilotOperationResetSummary(localRows: 0, remoteRows: remoteRows),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'pos_device_cleanup_failed',
          message: 'No se pudo limpiar las pruebas del dispositivo.',
          cause: error,
        ),
      );
    }
  }

  /// Renames an initialized POS device so utilities are easier to read.
  Future<AppResult<void>> renameDevice({
    required String deviceId,
    required String name,
  }) async {
    try {
      await _postRpc(
        rpcName: 'app_rename_pos_device',
        body: {
          'p_restaurant_id': _restaurantService.restaurantId,
          'p_device_id': deviceId,
          'p_name': name.trim(),
        },
      );
      return const AppSuccess(null);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'pos_device_rename_failed',
          message: 'No se pudo renombrar el dispositivo POS.',
          cause: error,
        ),
      );
    }
  }

  Future<Object?> _postRpc({
    required Map<String, Object?> body,
    required String rpcName,
  }) async {
    final token = _remoteSessionService.accessToken;
    if (!_config.isConfigured ||
        !_restaurantService.isConfigured ||
        token == null) {
      throw StateError('Se requiere sesion administrativa remota.');
    }

    final response = await _client.post(
      _config.rpcUri(rpcName),
      headers: {
        'apikey': _config.publishableKey,
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        _remoteSessionService.expire();
      }
      throw StateError(
        'Supabase rechazo $rpcName (${response.statusCode}): '
        '${response.body}',
      );
    }
    return jsonDecode(response.body);
  }
}
