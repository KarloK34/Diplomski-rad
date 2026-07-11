/// Central route paths used by the app router.
abstract final class AppRoutes {
  /// Dashboard tab path.
  static const home = '/';

  /// Recording tab path.
  static const record = '/record';

  /// Session history and insights tab path.
  static const sessions = '/sessions';

  /// Profile tab path.
  static const profile = '/profile';

  /// Settings path, nested under the profile tab.
  static const profileSettings = '/profile/settings';
}

/// Top-level tab identifiers.
enum AppTab {
  /// Dashboard tab.
  home,

  /// Recording tab.
  record,

  /// Session history and insights tab.
  sessions,

  /// Profile tab.
  profile,
}
