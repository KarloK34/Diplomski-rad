/// Project-wide maximum length for one recording session.
///
/// This is a local engineering limit, not an academic claim: the app keeps it
/// shared between the UI countdown and the foreground-service guard so both
/// paths enforce the same deadline.
const Duration defaultMaxSessionDuration = Duration(minutes: 30);

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
