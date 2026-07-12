/// Central route paths used by the app router.
abstract final class AppRoutes {
  /// Dashboard tab path.
  static const home = '/';

  /// Recording tab path.
  static const record = '/record';

  /// Relative path segment for [recordSummary], nested under [record].
  static const recordSummarySegment = 'summary';

  /// Finished-session summary path, nested under the recording tab.
  static const recordSummary = '/record/$recordSummarySegment';

  /// Relative path segment for [recordDebugSensors], nested under [record].
  static const recordDebugSensorsSegment = 'debug-sensors';

  /// Debug sensors path, nested under the recording tab.
  static const recordDebugSensors = '/record/$recordDebugSensorsSegment';

  /// Relative path segment shared by [recordSettings] and [profileSettings].
  static const settingsSegment = 'settings';

  /// Settings path, nested under the recording tab so it's reachable from
  /// Live HAR without switching to the profile tab. Mirrors
  /// [profileSettings], which serves the same screen from the profile tab.
  static const recordSettings = '/record/$settingsSegment';

  /// Session history and insights tab path.
  static const sessions = '/sessions';

  /// Profile tab path.
  static const profile = '/profile';

  /// Settings path, nested under the profile tab.
  static const profileSettings = '/profile/$settingsSegment';
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

/// Named sub-routes nested under a tab route, used as the GoRoute name.
enum AppSubRoute {
  /// Finished-session summary, nested under [AppTab.record].
  recordSummary,

  /// Debug sensors screen, nested under [AppTab.record].
  recordDebugSensors,

  /// Settings screen reached from [AppTab.record].
  recordSettings,

  /// Settings screen reached from [AppTab.profile].
  profileSettings,
}
