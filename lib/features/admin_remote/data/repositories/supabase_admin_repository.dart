import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/auth/domain/services/local_pin_hasher.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/catalog/domain/repositories/i_catalog_repository.dart';
import 'package:smoo_control/features/exchange_rates/domain/entities/exchange_rate.dart';
import 'package:smoo_control/features/exchange_rates/domain/repositories/i_exchange_rate_repository.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_catalog.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';
import 'package:smoo_control/features/modifiers/domain/repositories/i_modifiers_repository.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_stock_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/product_packaging_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/packaging/domain/repositories/i_packaging_repository.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/payment_methods/domain/repositories/i_payment_methods_repository.dart';
import 'package:smoo_control/features/products/data/models/product_option_group_codec.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/repositories/i_products_repository.dart';
import 'package:smoo_control/features/roles/domain/entities/access_permission.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';
import 'package:smoo_control/features/roles/domain/repositories/i_roles_repository.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';
import 'package:smoo_control/features/settings/domain/repositories/i_business_settings_repository.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/features/tables/domain/entities/table_account.dart';
import 'package:smoo_control/features/tables/domain/repositories/i_tables_repository.dart';
import 'package:smoo_control/features/users/domain/entities/app_user_profile.dart';
import 'package:smoo_control/features/users/domain/repositories/i_users_repository.dart';
part 'supabase_admin_repository_access_part.dart';
part 'supabase_admin_repository_base_part.dart';
part 'supabase_admin_repository_catalog_part.dart';
part 'supabase_admin_repository_error_part.dart';
part 'supabase_admin_repository_operations_part.dart';
part 'supabase_admin_repository_packaging_part.dart';
part 'supabase_admin_repository_settings_part.dart';
part 'supabase_admin_repository_units_part.dart';

/// Remote-only repository used by administrative screens.
///
/// POS dependencies keep using the local repositories registered under the
/// domain interfaces. Admin screens receive this concrete repository from the
/// service locator so admin reads and writes do not touch Drift or sync queue.
final class SupabaseAdminRepository extends _SupabaseAdminRepositoryBase
    with
        _SupabaseAdminCatalogMixin,
        _SupabaseAdminOperationsMixin,
        _SupabaseAdminSettingsMixin,
        _SupabaseAdminPackagingMixin,
        _SupabaseAdminAccessMixin,
        _SupabaseAdminUnitsMixin
    implements
        IAuditLogRepository,
        IBusinessSettingsRepository,
        ICatalogRepository,
        IExchangeRateRepository,
        IModifiersRepository,
        IPackagingRepository,
        IPaymentMethodsRepository,
        IProductsRepository,
        IRolesRepository,
        ITablesRepository,
        IUsersRepository {
  /// Creates the repository.
  const SupabaseAdminRepository({
    required super.config,
    required super.restaurantService,
    required super.remoteSessionService,
    required super.client,
    super.pinHasher = const LocalPinHasher(),
  });
}
