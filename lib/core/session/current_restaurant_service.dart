/// Provides the current restaurant context used by remote synchronization.
final class CurrentRestaurantService {
  /// Creates a current restaurant service.
  const CurrentRestaurantService({
    String restaurantId = const String.fromEnvironment('SMOO_RESTAURANT_ID'),
  }) : _restaurantId = restaurantId;

  final String _restaurantId;

  /// Current restaurant identifier in Supabase.
  String get restaurantId => _restaurantId.trim();

  /// Whether the app has a restaurant configured for remote sync.
  bool get isConfigured => restaurantId.isNotEmpty;
}
