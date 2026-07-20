import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the light/dark/system theme choice locally on the device.
///
/// A display preference, not account data — kept separate from
/// `UserProfileRepository`/Firestore so it applies instantly (including on
/// the pre-login screens) and independently per device.
class ThemePreferenceRepository {
  /// [preferences] is injectable for tests; defaults to the live instance.
  ThemePreferenceRepository({SharedPreferencesAsync? preferences})
    : _injectedPreferences = preferences;

  final SharedPreferencesAsync? _injectedPreferences;

  // Resolved lazily, not in the constructor: `SharedPreferencesAsync()`
  // throws immediately if no platform instance is registered, which is the
  // case in widget tests that build the full app — same reasoning as
  // `SessionRepository`'s lazy `FirebaseFirestore` access.
  SharedPreferencesAsync get _preferences =>
      _injectedPreferences ?? SharedPreferencesAsync();

  static const _key = 'themeMode';

  /// Returns the saved theme mode, or [ThemeMode.system] if unset or the
  /// read failed (e.g. no platform instance registered) — this must never
  /// throw, since it runs unawaited from `ThemeCubit`'s constructor.
  Future<ThemeMode> getThemeMode() async {
    try {
      final raw = await _preferences.getString(_key);
      return ThemeMode.values.firstWhere(
        (mode) => mode.name == raw,
        orElse: () => ThemeMode.system,
      );
    } on Object {
      return ThemeMode.system;
    }
  }

  /// Persists [mode] as the device's theme choice.
  Future<void> setThemeMode(ThemeMode mode) async {
    await _preferences.setString(_key, mode.name);
  }
}
