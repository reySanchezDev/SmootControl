import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/packaging/data/datasources/packaging_stock_exception.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_movement.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_stock_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/product_packaging_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/sales/data/models/sale_item_model.dart';
import 'package:uuid/uuid.dart';

part 'local_packaging_catalog_part.dart';
part 'local_packaging_movements_part.dart';
part 'local_packaging_support_part.dart';

/// Local datasource for sales types and packaging consumption.
final class LocalPackagingDataSource extends _LocalPackagingDataSourceBase
    with _LocalPackagingCatalogMixin, _LocalPackagingMovementsMixin {
  /// Creates the datasource.
  const LocalPackagingDataSource(super.database, {super.uuid});
}
