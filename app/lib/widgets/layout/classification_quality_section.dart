import 'package:flutter/material.dart';
import 'package:gait_sense/utils/gait_metric_info.dart';
import 'package:gait_sense/utils/gait_quality_format.dart';
import 'package:gait_sense/utils/session_metric_info.dart';
import 'package:gait_sense/utils/session_summary.dart';
import 'package:gait_sense/widgets/cards/info_card.dart';
import 'package:gait_sense/widgets/lists/labeled_value_row.dart';

/// HAR classification-quality metrics for a session: raw/smoothed agreement,
/// how much smoothing changed, and whether locomotion was stable enough to
/// support gait-parameter estimation.
class ClassificationQualitySection extends StatelessWidget {
  /// Creates the classification-quality section for [summary].
  const ClassificationQualitySection({required this.summary, super.key});

  /// Aggregated session quality metrics to display.
  final SessionQualitySummary summary;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'Kvaliteta klasifikacije',
      info: classificationQualitySectionMetricInfo,
      rows: [
        LabeledValueRow(
          label: 'Sirovi HAR rezultat',
          value: formatLabelCounts(summary.rawLabelWindowCounts),
          info: rawHarScoreMetricInfo,
        ),
        LabeledValueRow(
          label: 'Izglađeni HAR rezultat',
          value: formatLabelCounts(summary.effectiveLabelWindowCounts),
          info: smoothedHarScoreMetricInfo,
        ),
        LabeledValueRow(
          label: 'Sirove/izglađene promjene',
          value:
              '${windowCountLabelHr(summary.rawSmoothedChangeCount)} od '
              '${windowCountLabelHr(summary.predictionCount)}',
          info: rawSmoothedChangesMetricInfo,
        ),
        LabeledValueRow(
          label: 'Promijenjeni prozori',
          value: formatPercentHr(summary.rawSmoothedChangeFraction),
          info: changedWindowsMetricInfo,
        ),
        LabeledValueRow(
          label: 'Stabilna lokomocija',
          value: summary.hasEnoughStableLocomotion ? 'Da' : 'Ne',
          info: stableLocomotionMetricInfo,
        ),
        LabeledValueRow(
          label: 'Trajanje stabilne lokomocije',
          value: formatDurationSecondsHr(summary.stableLocomotionDuration),
          info: stableLocomotionDurationMetricInfo,
        ),
      ],
    );
  }
}
