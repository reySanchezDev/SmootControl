import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';
import 'package:smoo_control/features/settings/domain/repositories/i_business_settings_repository.dart';
import 'package:smoo_control/features/settings/presentation/bloc/business_settings_bloc.dart';
import 'package:smoo_control/features/settings/presentation/bloc/business_settings_event.dart';
import 'package:smoo_control/features/settings/presentation/bloc/business_settings_state.dart';

void main() {
  group('BusinessSettingsBloc', () {
    const settings = BusinessSettings(
      businessName: 'Smoo',
      showCompanyInfoOnReceipts: true,
      invoicePrefix: 'SM',
      initialInvoiceNumber: 1,
      nextInvoiceNumber: 1,
    );

    blocTest<BusinessSettingsBloc, BusinessSettingsState>(
      'saves settings and writes audit log',
      setUp: () {
        audit = AuditLogRepositoryFake();
      },
      build: () => BusinessSettingsBloc(
        repository: const _BusinessSettingsRepositoryFake(settings),
        auditLogRepository: audit,
      ),
      act: (bloc) => bloc.add(const BusinessSettingsSaved(settings)),
      expect: () => const [
        BusinessSettingsLoading(),
        BusinessSettingsLoaded(settings, saved: true),
      ],
      verify: (_) {
        expect(audit.entries.single.action, 'settings.save');
        expect(audit.entries.single.entityName, 'business_settings');
      },
    );
  });
}

late AuditLogRepositoryFake audit;

final class _BusinessSettingsRepositoryFake
    implements IBusinessSettingsRepository {
  const _BusinessSettingsRepositoryFake(this.settings);

  final BusinessSettings settings;

  @override
  Future<AppResult<BusinessSettings>> getSettings() async {
    return AppSuccess(settings);
  }

  @override
  Future<AppResult<BusinessSettings>> saveSettings(
    BusinessSettings settings, {
    bool syncRemote = true,
  }) async {
    return AppSuccess(settings);
  }
}

final class AuditLogRepositoryFake implements IAuditLogRepository {
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
