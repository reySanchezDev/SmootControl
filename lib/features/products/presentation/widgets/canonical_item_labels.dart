import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Returns localized labels for the article's independent dimensions.
String canonicalItemTypeLabel(
  AppLocalizations l10n,
  CanonicalItemType type,
) => switch (type) {
  CanonicalItemType.inventory => l10n.canonicalItemTypeInventory,
  CanonicalItemType.nonInventory => l10n.canonicalItemTypeNonInventory,
  CanonicalItemType.service => l10n.canonicalItemTypeService,
};

/// Returns the localized operational role; service remains a derived role.
String canonicalItemRoleLabel(
  AppLocalizations l10n,
  CanonicalItemClass itemClass,
) => switch (itemClass) {
  CanonicalItemClass.saleProduct => l10n.canonicalItemRoleSaleProduct,
  CanonicalItemClass.rawMaterial => l10n.canonicalItemRoleRawMaterial,
  CanonicalItemClass.packaging => l10n.canonicalItemRolePackaging,
  CanonicalItemClass.service => l10n.canonicalItemTypeService,
};
