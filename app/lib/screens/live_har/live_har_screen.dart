import 'package:flutter/material.dart';
import 'package:gait_sense/screens/live_har/live_har_content.dart';
import 'package:gait_sense/screens/live_har/live_har_listener.dart';

/// The recording screen: a single Start/Stop control over the background
/// recording service, plus the live readouts derived by `UiBloc`.
class LiveHarScreen extends StatelessWidget {
  /// Creates the live HAR screen.
  const LiveHarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LiveHarListener(child: LiveHarContent());
  }
}
