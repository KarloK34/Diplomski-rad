import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/gait_quality_format.dart';
import 'package:gait_sense/utils/session_summary.dart';
import 'package:gait_sense/widgets/cards/info_card.dart';
import 'package:gait_sense/widgets/lists/gait_segment_row.dart';
import 'package:gait_sense/widgets/lists/labeled_value_row.dart';

/// Session quality and gait-analysis metrics: raw/smoothed HAR agreement,
/// stable locomotion, cadence, walking speed, and level-walking candidates.
class SessionQualitySection extends StatelessWidget {
  /// Creates the quality section for [summary].
  const SessionQualitySection({required this.summary, super.key});

  /// Aggregated session quality metrics to display.
  final SessionQualitySummary summary;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final suitableGaitSegments = summary.suitableGaitSegments;
    return InfoCard(
      title: 'Pouzdanost sesije',
      rows: [
        LabeledValueRow(
          label: 'Raw HAR rezultat',
          value: formatLabelCounts(summary.rawLabelWindowCounts),
        ),
        LabeledValueRow(
          label: 'Smoothed HAR rezultat',
          value: formatLabelCounts(summary.effectiveLabelWindowCounts),
        ),
        LabeledValueRow(
          label: 'Raw/smoothed promjene',
          value:
              '${windowCountLabelHr(summary.rawSmoothedChangeCount)} od '
              '${windowCountLabelHr(summary.predictionCount)}',
        ),
        LabeledValueRow(
          label: 'Promijenjeni prozori',
          value: formatPercentHr(summary.rawSmoothedChangeFraction),
        ),
        LabeledValueRow(
          label: 'Stabilna lokomocija',
          value: summary.hasEnoughStableLocomotion ? 'Da' : 'Ne',
        ),
        LabeledValueRow(
          label: 'Trajanje stabilne lokomocije',
          value: formatDurationSecondsHr(summary.stableLocomotionDuration),
        ),
        SizedBox(height: spacing.xs),
        LabeledValueRow(
          label: 'Kandidati za analizu hoda',
          value: suitableGaitSegments.isEmpty
              ? 'Nema kandidata'
              : formatSegmentCountHr(suitableGaitSegments.length),
        ),
        LabeledValueRow(
          label: 'Trajanje stabilnog hodanja po ravnom',
          value: formatDurationSecondsHr(summary.levelWalkingGaitDuration),
        ),
        SizedBox(height: spacing.xs),
        LabeledValueRow(
          label: 'Kadenca (eksperimentalno)',
          value: formatCadenceHr(summary.gaitCadence),
        ),
        LabeledValueRow(
          label: 'Detektirani koraci (eksperimentalno)',
          value: formatStepCountHr(summary.gaitCadence),
        ),
        if (summary.gaitCadence.hasComputedCadence)
          LabeledValueRow(
            label: 'Pouzdanost procjene',
            value: formatCadenceConfidenceHr(summary.gaitCadence.confidence),
          ),
        if (summary.gaitCadence.hasComputedCadence &&
            summary.gaitCadence.confidenceReason != null)
          LabeledValueRow(
            label: 'Napomena',
            value: formatCadenceConfidenceReasonHr(
              summary.gaitCadence.confidenceReason,
            ),
          ),
        if (summary.gaitCadence.temporalParameters case final temporal?) ...[
          LabeledValueRow(
            label: 'Prosječno vrijeme koraka (eksperimentalno)',
            value: formatDurationSecondsHr(temporal.meanStepTime),
          ),
          if (temporal.meanStrideTime case final strideTime?)
            LabeledValueRow(
              label: 'Prosječno vrijeme iskoraka (eksperimentalno)',
              value: formatDurationSecondsHr(strideTime),
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
          LabeledValueRow(
            label: 'Regularnost signala (indikator kvalitete)',
            value: formatGaitRegularityHr(temporal.gaitRegularity),
          ),
        ],
        if (!summary.gaitCadence.hasComputedCadence)
          LabeledValueRow(
            label: 'Razlog',
            value: formatCadenceUnavailableReasonHr(
              summary.gaitCadence.reason,
            ),
          ),
        SizedBox(height: spacing.xs),
        LabeledValueRow(
          label: 'Brzina hoda (gruba procjena)',
          value: formatWalkingSpeedHr(summary.gaitWalkingSpeed),
        ),
        LabeledValueRow(
          label: 'Duljina koraka (gruba procjena)',
          value: formatStepLengthHr(summary.gaitWalkingSpeed),
        ),
        if (!summary.gaitWalkingSpeed.hasComputedSpeed)
          LabeledValueRow(
            label: 'Razlog brzine hoda',
            value: formatWalkingSpeedUnavailableReasonHr(
              summary.gaitWalkingSpeed,
            ),
          ),
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
