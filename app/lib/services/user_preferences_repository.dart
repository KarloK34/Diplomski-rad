import 'package:shared_preferences/shared_preferences.dart';

/// Persists lightweight user preferences (currently only body height) using
/// the platform key-value store.
///
/// Height is stored as a [double] in centimetres under [_heightKey].  No
/// defaults are provided: a null return means the user has not yet entered a
/// value, and callers must handle that case explicitly.
class UserPreferencesRepository {
  static const String _heightKey = 'user_height_cm';

  /// Returns the stored body height in centimetres, or null if the user has
  /// not yet provided one.
  Future<double?> getHeightCm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_heightKey);
  }

  /// Persists [heightCm].  The value must be positive.
  Future<void> setHeightCm(double heightCm) async {
    assert(heightCm > 0, 'heightCm must be positive');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_heightKey, heightCm);
  }

  /// Removes the stored height, returning to the no-height state.
  Future<void> clearHeight() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_heightKey);
  }
}
