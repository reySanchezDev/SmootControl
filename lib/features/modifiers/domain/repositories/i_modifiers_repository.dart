import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_catalog.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';

/// Contract for reusable POS modifiers.
abstract interface class IModifiersRepository {
  /// Returns the complete modifier catalog.
  Future<AppResult<ModifierCatalog>> getCatalog();

  /// Saves a modifier group.
  Future<AppResult<ModifierGroup>> saveGroup(ModifierGroup group);

  /// Saves a modifier option.
  Future<AppResult<ModifierOption>> saveOption(ModifierOption option);

  /// Saves only the local POS availability for a modifier option.
  Future<AppResult<ModifierOption>> saveOptionAvailability(
    ModifierOption option,
  );
}
