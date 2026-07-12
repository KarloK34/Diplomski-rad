import 'package:flutter/material.dart';

/// Placeholder shown while the session summary is being computed.
class SessionSummaryLoadingView extends StatelessWidget {
  /// Creates the loading placeholder.
  const SessionSummaryLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sažetak sesije')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
