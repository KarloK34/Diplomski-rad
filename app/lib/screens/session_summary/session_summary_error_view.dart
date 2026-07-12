import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:go_router/go_router.dart';

/// Placeholder shown when session summary computation fails.
class SessionSummaryErrorView extends StatelessWidget {
  /// Creates the error placeholder for [error].
  const SessionSummaryErrorView({required this.error, super.key});

  /// The error thrown while computing the summary.
  final Object error;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Scaffold(
      appBar: AppBar(title: const Text('Sažetak sesije')),
      body: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.colors.error),
            SizedBox(height: spacing.md),
            Text(
              'Nije moguće izračunati sažetak sesije.',
              style: context.textStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.xs),
            Text(
              error.toString(),
              style: context.textStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.lg),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Natrag'),
            ),
          ],
        ),
      ),
    );
  }
}
