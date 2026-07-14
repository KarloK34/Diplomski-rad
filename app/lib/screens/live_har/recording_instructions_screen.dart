import 'package:flutter/material.dart';
import 'package:gait_sense/screens/live_har/recording_placement_copy.dart';
import 'package:gait_sense/widgets/widgets.dart';

/// On-demand reminder of how to place the phone for a good session, reached
/// via the info icon on the record tab. Read-only — no live status, no CTA —
/// shares its copy with onboarding's placement step so wording never drifts.
class RecordingInstructionsScreen extends StatelessWidget {
  /// Creates the reminder screen.
  const RecordingInstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upute')),
      body: const Center(
        child: OnboardingStepView(
          imageAsset: RecordingPlacementCopy.imageAsset,
          title: RecordingPlacementCopy.title,
          description: RecordingPlacementCopy.description,
        ),
      ),
    );
  }
}
