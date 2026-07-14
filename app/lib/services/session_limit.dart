/// Project-wide maximum length for one recording session.
///
/// This is a local engineering limit, not an academic claim: the app keeps it
/// shared between the UI countdown and the foreground-service guard so both
/// paths enforce the same deadline.
const Duration defaultMaxSessionDuration = Duration(minutes: 30);

/// How long the pre-recording countdown runs after Start is pressed.
///
/// A local UX/engineering choice, not an academic claim: long enough to
/// pocket the phone, short enough not to feel like a delay. Also doubles as
/// the timeout for the sensor-readiness probe (see
/// `RecordingSessionBloc._onStarted`) — trivially retunable if either need
/// changes.
const Duration defaultPreparationDuration = Duration(seconds: 7);

/// Returns true at the first instant that belongs outside the allowed session.
bool hasReachedSessionLimit({
  required DateTime startedAt,
  required DateTime now,
  Duration maxDuration = defaultMaxSessionDuration,
}) {
  if (maxDuration <= Duration.zero) {
    throw ArgumentError.value(
      maxDuration,
      'maxDuration',
      'must be positive',
    );
  }
  return !now.isBefore(startedAt.add(maxDuration));
}
