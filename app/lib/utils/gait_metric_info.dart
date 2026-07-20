import 'package:gait_sense/models/metric_info.dart';

/// Plain-language explanations for the gait-analysis metrics shown in
/// `ClassificationQualitySection` and `GaitParametersSection`, surfaced via
/// `MetricInfoButton`.

// ---------------------------------------------------------------------------
// Gait-analysis eligibility
// ---------------------------------------------------------------------------

/// Explanation for the "Stabilna lokomocija" flag.
const MetricInfo stableLocomotionMetricInfo = MetricInfo(
  title: 'Stabilna lokomocija',
  description:
      'Označava ima li sesija dovoljno neprekinutog hodanja ili trčanja da '
      'bi parametri hoda mogli biti procijenjeni.',
);

/// Explanation for the stable-locomotion duration.
const MetricInfo stableLocomotionDurationMetricInfo = MetricInfo(
  title: 'Trajanje stabilne lokomocije',
  description:
      'Ukupno trajanje razdoblja unutar sesije prepoznatih kao neprekinuto '
      'hodanje ili trčanje.',
);

/// Explanation for the gait-candidate segment count.
const MetricInfo gaitCandidatesMetricInfo = MetricInfo(
  title: 'Kandidati za analizu hoda',
  description:
      'Broj odsječaka hodanja po ravnoj podlozi dovoljno dugih i stabilnih '
      'da se iz njih računaju parametri hoda (kadenca, brzina, duljina '
      'koraka).',
);

/// Explanation for the level-walking duration.
const MetricInfo levelWalkingDurationMetricInfo = MetricInfo(
  title: 'Trajanje stabilnog hodanja po ravnom',
  description:
      'Ukupno trajanje odsječaka hodanja po ravnoj podlozi korištenih za '
      'procjenu parametara hoda.',
);

// ---------------------------------------------------------------------------
// Gait parameters
// ---------------------------------------------------------------------------

/// Explanation for cadence.
const MetricInfo cadenceMetricInfo = MetricInfo(
  title: 'Kadenca',
  description:
      'Broj koraka u minuti, procijenjen iz periodičnosti signala '
      'akcelerometra tijekom hodanja po ravnom.',
);

/// Explanation for the detected step count.
const MetricInfo stepCountMetricInfo = MetricInfo(
  title: 'Detektirani koraci',
  description:
      'Ukupan broj pojedinačnih koraka prepoznatih u odsječcima korištenim '
      'za procjenu kadence.',
);

/// Explanation for the cadence-estimate confidence label.
const MetricInfo cadenceConfidenceMetricInfo = MetricInfo(
  title: 'Pouzdanost procjene',
  description:
      'Koliko se procjene kadence dobivene iz vrhova signala i iz '
      'dominantnog perioda signala slažu — veće slaganje znači pouzdaniju '
      'procjenu.',
);

/// Explanation for mean step time.
const MetricInfo meanStepTimeMetricInfo = MetricInfo(
  title: 'Prosječno vrijeme koraka',
  description:
      'Prosječno vrijeme između dva uzastopna koraka (lijevog i desnog), '
      'izračunato iz detektiranih koraka.',
);

/// Explanation for mean stride time.
const MetricInfo meanStrideTimeMetricInfo = MetricInfo(
  title: 'Prosječno vrijeme iskoraka',
  description:
      'Prosječno vrijeme jednog potpunog cikla hoda — od koraka jedne noge '
      'do sljedećeg koraka iste noge.',
);

/// Explanation for signal regularity.
const MetricInfo signalRegularityMetricInfo = MetricInfo(
  title: 'Regularnost signala',
  description:
      'Pokazatelj koliko je signal hodanja periodičan i čist, izračunat '
      'autokorelacijom. Koristi se kao indikator kvalitete signala, a ne '
      'kao klinička mjera hoda.',
);

/// Explanation for walking speed.
const MetricInfo walkingSpeedMetricInfo = MetricInfo(
  title: 'Brzina hoda',
  description:
      'Gruba procjena brzine hodanja, izračunata iz kadence i procijenjene '
      'duljine koraka pomoću modela obrnutog njihala i visine korisnika. '
      'Točnost ovisi o položaju telefona i nije klinički validirana.',
);

/// Explanation for step length.
const MetricInfo stepLengthMetricInfo = MetricInfo(
  title: 'Duljina koraka',
  description:
      'Gruba procjena duljine jednog koraka, izračunata iz kadence i '
      'visine korisnika pomoću modela obrnutog njihala. Točnost ovisi o '
      'položaju telefona i nije klinički validirana.',
);
