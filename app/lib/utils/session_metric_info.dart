import 'package:gait_sense/models/metric_info.dart';

/// Plain-language explanations for the session-overview, section-header, and
/// classification-quality metrics shown on the session summary and session
/// detail screens, surfaced via `MetricInfoButton`.

// ---------------------------------------------------------------------------
// Session overview
// ---------------------------------------------------------------------------

/// Explanation for the session start timestamp.
const MetricInfo sessionStartMetricInfo = MetricInfo(
  title: 'Početak',
  description: 'Vrijeme kada je snimanje sesije započelo, prema satu uređaja.',
);

/// Explanation for the session duration.
const MetricInfo sessionDurationMetricInfo = MetricInfo(
  title: 'Trajanje',
  description: 'Ukupno vrijeme od početka do kraja snimanja sesije.',
);

/// Explanation for the total prediction count.
const MetricInfo predictionCountMetricInfo = MetricInfo(
  title: 'Broj predikcija',
  description:
      'Broj klasifikacijskih prozora koje je model prepoznavanja aktivnosti '
      'obradio tijekom sesije — svaki prozor pokriva kratki isječak signala '
      'senzora.',
);

// ---------------------------------------------------------------------------
// Section headers
// ---------------------------------------------------------------------------

/// Explanation for the "Parametri hoda" section.
const MetricInfo gaitParametersSectionMetricInfo = MetricInfo(
  title: 'Parametri hoda',
  description:
      'Procijenjeni parametri hoda (kadenca, brzina, duljina koraka) i '
      'odsječci hodanja po ravnom korišteni za tu procjenu.',
);

/// Explanation for the "Kvaliteta klasifikacije" section.
const MetricInfo classificationQualitySectionMetricInfo = MetricInfo(
  title: 'Kvaliteta klasifikacije',
  description:
      'Pokazatelji koliko je pouzdana klasifikacija aktivnosti u ovoj '
      'sesiji: slaganje sirovog i izglađenog izlaza modela te ima li '
      'sesija dovoljno neprekinutog hodanja ili trčanja.',
);

/// Explanation for the "Udio po aktivnosti" section.
const MetricInfo activityTotalsMetricInfo = MetricInfo(
  title: 'Udio po aktivnosti',
  description:
      'Ukupno vrijeme i postotak sesije koje je model prepoznao kao svaku '
      'pojedinu aktivnost.',
);

/// Explanation for the "Vremenski slijed" section.
const MetricInfo timelineMetricInfo = MetricInfo(
  title: 'Vremenski slijed',
  description:
      'Kronološki prikaz prepoznatih aktivnosti tijekom sesije, podijeljen '
      'u uzastopne odsječke.',
);

// ---------------------------------------------------------------------------
// Classification quality
// ---------------------------------------------------------------------------

/// Explanation for the raw HAR window counts.
const MetricInfo rawHarScoreMetricInfo = MetricInfo(
  title: 'Sirovi HAR rezultat',
  description:
      'Broj prozora po svakoj aktivnosti prema izlazu modela, bez ikakvog '
      'vremenskog izglađivanja.',
);

/// Explanation for the smoothed HAR window counts.
const MetricInfo smoothedHarScoreMetricInfo = MetricInfo(
  title: 'Izglađeni HAR rezultat',
  description:
      'Broj prozora po svakoj aktivnosti nakon vremenskog izglađivanja, '
      'koje uklanja kratkotrajne, izolirane promjene oznake koje najčešće '
      'nisu stvarna promjena aktivnosti.',
);

/// Explanation for the raw/smoothed change count.
const MetricInfo rawSmoothedChangesMetricInfo = MetricInfo(
  title: 'Sirove/izglađene promjene',
  description:
      'Broj prozora u kojima se izglađena oznaka aktivnosti razlikuje od '
      'sirovog izlaza modela — pokazatelj koliko je izglađivanje utjecalo '
      'na rezultat.',
);

/// Explanation for the changed-windows percentage.
const MetricInfo changedWindowsMetricInfo = MetricInfo(
  title: 'Promijenjeni prozori',
  description:
      'Udio svih prozora u sesiji čija je oznaka aktivnosti promijenjena '
      'izglađivanjem.',
);
