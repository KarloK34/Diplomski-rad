import 'package:flutter/material.dart';
import 'package:gait_sense/screens/sessions/sessions_content.dart';
import 'package:gait_sense/screens/sessions/sessions_provider.dart';

/// Session history and insights tab: a filterable, paginated list of saved
/// sessions plus cross-session trend charts.
class SessionsScreen extends StatelessWidget {
  /// Creates the sessions screen.
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SessionsProvider(child: SessionsContent());
  }
}
