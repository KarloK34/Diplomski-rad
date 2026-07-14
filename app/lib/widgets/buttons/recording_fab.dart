import 'package:flutter/material.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_state.dart';

/// Start/Stop control whose appearance follows the recording [status].
class RecordingFab extends StatelessWidget {
  /// Creates the control, invoking [onStart], [onStop], or [onCancel]
  /// depending on [status].
  const RecordingFab({
    required this.status,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    this.countdownSecondsRemaining = 0,
    super.key,
  });

  /// Current recording lifecycle state.
  final RecordingStatus status;

  /// Invoked when tapped while idle, saved, or unavailable (retry).
  final VoidCallback onStart;

  /// Invoked when tapped while recording.
  final VoidCallback onStop;

  /// Invoked when tapped while preparing (cancels the countdown).
  final VoidCallback onCancel;

  /// Seconds left in the countdown; only meaningful while [status] is
  /// [RecordingStatus.preparing].
  final int countdownSecondsRemaining;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case RecordingStatus.preparing:
        return FloatingActionButton.extended(
          onPressed: onCancel,
          icon: const Icon(Icons.close),
          label: Text('Otkaži (${countdownSecondsRemaining}s)'),
        );
      case RecordingStatus.saving:
        return const FloatingActionButton.extended(
          onPressed: null,
          icon: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: Text('Spremanje…'),
        );
      case RecordingStatus.recording:
        return FloatingActionButton.extended(
          onPressed: onStop,
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
        );
      case RecordingStatus.unavailable:
        return FloatingActionButton.extended(
          onPressed: onStart,
          icon: const Icon(Icons.refresh),
          label: const Text('Pokušaj ponovno'),
        );
      case RecordingStatus.idle:
      case RecordingStatus.saved:
        return FloatingActionButton.extended(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start'),
        );
    }
  }
}
