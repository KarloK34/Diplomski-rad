import 'package:flutter/material.dart';
import 'package:gait_sense/blocs/ui/ui_state.dart';

/// Start/Stop control whose appearance follows the recording [status].
class RecordingFab extends StatelessWidget {
  /// Creates the control, invoking [onStart] or [onStop] depending on
  /// [status].
  const RecordingFab({
    required this.status,
    required this.onStart,
    required this.onStop,
    super.key,
  });

  /// Current recording lifecycle state.
  final RecordingStatus status;

  /// Invoked when tapped while idle or saved.
  final VoidCallback onStart;

  /// Invoked when tapped while recording.
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    switch (status) {
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
