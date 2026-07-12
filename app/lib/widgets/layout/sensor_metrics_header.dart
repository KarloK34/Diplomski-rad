import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Status, measured sampling rate, and sample count above a channel
/// statistics table.
class SensorMetricsHeader extends StatelessWidget {
  /// Creates the header for a stream that is [isRunning], sampling at
  /// [measuredHertz] with [sampleCount] samples received so far.
  const SensorMetricsHeader({
    required this.isRunning,
    required this.measuredHertz,
    required this.sampleCount,
    super.key,
  });

  /// Whether the stream is currently sampling.
  final bool isRunning;

  /// Effective sampling rate, in Hz.
  final double measuredHertz;

  /// Total samples received in the current run.
  final int sampleCount;

  /// Tolerance band around the ~50 Hz target rate.
  static const _expectedHertzMin = 48;
  static const _expectedHertzMax = 52;

  @override
  Widget build(BuildContext context) {
    final hertzInRange =
        measuredHertz >= _expectedHertzMin &&
        measuredHertz <= _expectedHertzMax;
    final appTextStyles = context.appTextStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status: ${isRunning ? "aktivno" : "zaustavljeno"}',
          style: context.textStyles.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Rate: ${measuredHertz.toStringAsFixed(1)} Hz'
          '${isRunning ? (hertzInRange ? "  ✓" : "  ⚠") : ""}',
          style: isRunning && !hertzInRange ? appTextStyles.warning : null,
        ),
        Text('Uzoraka: $sampleCount'),
        const SizedBox(height: 4),
        Text(
          'μ / σ akumulirano od Start-a',
          style: context.textStyles.bodySmall,
        ),
      ],
    );
  }
}
