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

  /// Relative path segment for [recordRecoveredSummary], nested under
  /// [record]. Only reachable via `context.push` with a recovered
  /// `SessionLog` passed as `extra` — there is nothing else to deep-link to.
  static const recordRecoveredSummarySegment = 'recovered-summary';

  /// Recovered-session summary path, nested under the recording tab, for a
  /// session found on disk that outlived an app kill before it was saved or
  /// discarded.
  static const recordRecoveredSummary =
      '/record/$recordRecoveredSummarySegment';

  /// Relative path segment for [recordDebugSensors], nested under [record].
  static const recordDebugSensorsSegment = 'debug-sensors';

  /// Debug sensors path, nested under the recording tab.
  static const recordDebugSensors = '/record/$recordDebugSensorsSegment';

  /// Relative path segment for [recordInstructions], nested under [record].
  static const recordInstructionsSegment = 'instructions';

  /// On-demand placement-instructions reminder, nested under the recording
  /// tab (reachable via the info icon in its app bar).
  static const recordInstructions = '/record/$recordInstructionsSegment';

  /// Relative path segment shared by [recordSettings] and [profileSettings].
  static const settingsSegment = 'settings';

  /// Settings path, nested under the recording tab so it's reachable from
  /// Live HAR without switching to the profile tab. Mirrors
  /// [profileSettings], which serves the same screen from the profile tab.
  static const recordSettings = '/record/$settingsSegment';

  /// Session history and insights tab path.
  static const sessions = '/sessions';

  /// Relative path segment for [sessionDetail], nested under [sessions].
  static const sessionDetailSegment = ':sessionId';

  /// Detail path for the session identified by [sessionId] (its ISO-8601 start
  /// time). The id is percent-encoded since it contains `:` and `.`.
  static String sessionDetail(String sessionId) =>
      '/sessions/${Uri.encodeComponent(sessionId)}';

  /// Profile tab path.
  static const profile = '/profile';

  /// Settings path, nested under the profile tab.
  static const profileSettings = '/profile/$settingsSegment';

  /// Shown while sign-in status is not yet known.
  static const splash = '/splash';

  /// Login path.
  static const login = '/login';

  /// Signup path.
  static const signup = '/signup';

  /// Shown once per account, right after first sign-in, until the account
  /// completes it.
  static const onboarding = '/onboarding';
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

  /// Recovered-session summary, nested under [AppTab.record].
  recordRecoveredSummary,

  /// Debug sensors screen, nested under [AppTab.record].
  recordDebugSensors,

  /// On-demand placement-instructions reminder, nested under [AppTab.record].
  recordInstructions,

  /// Settings screen reached from [AppTab.record].
  recordSettings,

  /// Settings screen reached from [AppTab.profile].
  profileSettings,

  /// Saved-session detail, nested under [AppTab.sessions].
  sessionDetail,
}
