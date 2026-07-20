import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/gait_metric_info.dart';
import 'package:gait_sense/utils/gait_quality_format.dart';
import 'package:gait_sense/utils/session_metric_info.dart';
import 'package:gait_sense/utils/session_summary.dart';
import 'package:gait_sense/widgets/cards/info_card.dart';
import 'package:gait_sense/widgets/lists/gait_segment_row.dart';
import 'package:gait_sense/widgets/lists/labeled_value_row.dart';

/// Computed gait-analysis parameters for a session: walking speed and step
/// length, cadence and temporal parameters — then supporting diagnostics
/// (detected steps, signal regularity, level-walking candidates, duration).
class GaitParametersSection extends StatelessWidget {
  /// Creates the gait-parameters section for [summary].
  const GaitParametersSection({required this.summary, super.key});

  /// Aggregated session quality metrics to display.
  final SessionQualitySummary summary;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final suitableGaitSegments = summary.suitableGaitSegments;
    return InfoCard(
      title: 'Parametri hoda',
      info: gaitParametersSectionMetricInfo,
      rows: [
        LabeledValueRow(
          label: 'Brzina hoda',
          value: formatWalkingSpeedHr(summary.gaitWalkingSpeed),
          info: walkingSpeedMetricInfo,
        ),
        LabeledValueRow(
          label: 'Duljina koraka',
          value: formatStepLengthHr(summary.gaitWalkingSpeed),
          info: stepLengthMetricInfo,
        ),
        if (!summary.gaitWalkingSpeed.hasComputedSpeed)
          LabeledValueRow(
            label: 'Razlog brzine hoda',
            value: formatWalkingSpeedUnavailableReasonHr(
              summary.gaitWalkingSpeed,
            ),
          ),
        SizedBox(height: spacing.xs),
        LabeledValueRow(
          label: 'Kadenca',
          value: formatCadenceHr(summary.gaitCadence),
          info: cadenceMetricInfo,
        ),
        if (summary.gaitCadence.hasComputedCadence)
          LabeledValueRow(
            label: 'Pouzdanost procjene',
            value: formatCadenceConfidenceHr(summary.gaitCadence.confidence),
            info: cadenceConfidenceMetricInfo,
          ),
        if (summary.gaitCadence.hasComputedCadence &&
            summary.gaitCadence.confidenceReason != null)
          LabeledValueRow(
            label: 'Napomena',
            value: formatCadenceConfidenceReasonHr(
              summary.gaitCadence.confidenceReason,
            ),
          ),
        if (!summary.gaitCadence.hasComputedCadence)
          LabeledValueRow(
            label: 'Razlog',
            value: formatCadenceUnavailableReasonHr(
              summary.gaitCadence.reason,
            ),
          ),
        if (summary.gaitCadence.temporalParameters case final temporal?) ...[
          LabeledValueRow(
            label: 'Prosječno vrijeme koraka',
            value: formatDurationSecondsHr(temporal.meanStepTime),
            info: meanStepTimeMetricInfo,
          ),
          if (temporal.meanStrideTime case final strideTime?)
            LabeledValueRow(
              label: 'Prosječno vrijeme iskoraka',
              value: formatDurationSecondsHr(strideTime),
              info: meanStrideTimeMetricInfo,
            ),
        ],
        if (summary.gaitCadence.hasComputedCadence ||
            summary.gaitWalkingSpeed.hasComputedSpeed)
          Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: Text(
              gaitAnalysisLimitationsNoteHr,
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        SizedBox(height: spacing.xs),
        LabeledValueRow(
          label: 'Detektirani koraci',
          value: formatStepCountHr(summary.gaitCadence),
          info: stepCountMetricInfo,
        ),
        // Step-time / stride-time / cadence variability (CV) is intentionally
        // not displayed: a single pocket IMU cannot time individual gait
        // events accurately enough for a defensible gait-variability figure
        // (Mobbs et al., 2022, https://doi.org/10.21037/mhealth-21-17), so a
        // CV here would reflect detector jitter and sample-rate quantization
        // rather than gait physiology. The values are still computed on
        // GaitTemporalParameters (and exported) for offline validation. The
        // autocorrelation-based regularity below is kept instead, as a
        // signal-quality descriptor (Moe-Nilssen & Helbostad, 2004,
        // https://doi.org/10.1016/S0021-9290(03)00233-1).
        if (summary.gaitCadence.temporalParameters case final temporal?)
          LabeledValueRow(
            label: 'Regularnost signala',
            value: formatGaitRegularityHr(temporal.gaitRegularity),
            info: signalRegularityMetricInfo,
          ),
        LabeledValueRow(
          label: 'Kandidati za analizu hoda',
          value: suitableGaitSegments.isEmpty
              ? 'Nema kandidata'
              : formatSegmentCountHr(suitableGaitSegments.length),
          info: gaitCandidatesMetricInfo,
        ),
        LabeledValueRow(
          label: 'Trajanje stabilnog hodanja po ravnom',
          value: formatDurationSecondsHr(summary.levelWalkingGaitDuration),
          info: levelWalkingDurationMetricInfo,
        ),
        if (suitableGaitSegments.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: Text(
              'Parametri hoda nisu izračunati jer nema dovoljno stabilnog '
              'hodanja po ravnom.',
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.error,
              ),
            ),
          )
        else ...[
          SizedBox(height: spacing.xxs),
          for (final segment in suitableGaitSegments)
            GaitSegmentRow(
              timeRangeLabel: formatGaitSegmentTimeRange(segment),
              windowCountLabel: windowCountLabelHr(segment.windows),
              labelCountsLabel: formatLabelCounts(segment.labelCounts),
            ),
        ],
      ],
    );
  }
}
