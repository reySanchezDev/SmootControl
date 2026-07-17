import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/recipes/domain/entities/product_recipe.dart';

part 'supabase_product_recipes_service_rows_part.dart';

/// Remote administrative service for product recipes.
final class SupabaseProductRecipesService {
  /// Creates the service.
  const SupabaseProductRecipesService({
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required CurrentRemoteSessionService remoteSessionService,
    required http.Client client,
  }) : _config = config,
       _restaurantService = restaurantService,
       _remoteSessionService = remoteSessionService,
       _client = client;

  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final CurrentRemoteSessionService _remoteSessionService;
  final http.Client _client;

  /// Loads the active recipe for a product, if it exists.
  Future<AppResult<ProductRecipe?>> loadActiveRecipe(String productId) async {
    return _guard('recipe_read_failed', 'No se pudo leer la receta.', () async {
      final recipes = await _getRows('product_recipes', {
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'product_id': 'eq.$productId',
        'status': 'eq.active',
        'select': 'id,product_id,version',
        'limit': '1',
      });
      if (recipes.isEmpty) return null;
      final recipe = recipes.first;
      final lines = await _recipeLines(_text(recipe['id']));
      return ProductRecipe(
        id: _text(recipe['id']),
        productId: _text(recipe['product_id']),
        version: _int(recipe['version'], fallback: 1),
        lines: lines,
      );
    });
  }

  /// Saves a new active recipe version.
  Future<AppResult<void>> saveRecipe({
    required String productId,
    required List<ProductRecipeLine> lines,
  }) async {
    return _guard('recipe_save_failed', 'No se pudo guardar la receta.', () {
      return _postRpc('app_save_product_recipe', {
        'p_restaurant_id': _restaurantService.restaurantId,
        'p_product_id': productId,
        'p_lines': [
          for (final line in lines)
            {
              'component_product_id': line.componentProductId,
              'quantity': line.quantity,
              'unit_id': line.unitId,
              'waste_percent': line.wastePercent,
              'display_order': line.displayOrder,
            },
        ],
      });
    });
  }

  Future<AppResult<T>> _guard<T>(
    String code,
    String message,
    Future<T> Function() action,
  ) async {
    try {
      _ensureReady();
      return AppSuccess(await action());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: code,
          message: _friendlyMessage(message, error),
          cause: error,
        ),
      );
    }
  }

  String _friendlyMessage(String fallback, Object error) {
    final text = error.toString();
    final jsonStart = text.indexOf('{');
    if (jsonStart >= 0) {
      try {
        final decoded = jsonDecode(text.substring(jsonStart));
        if (decoded is Map && decoded['message'] != null) {
          return decoded['message'].toString();
        }
      } on Object {
        // Keep the generic message when the remote body is not JSON.
      }
    }
    if (text.contains('Sesion remota expirada')) {
      return 'La sesion remota expiro. Vuelve a iniciar sesion.';
    }
    return fallback;
  }
}
