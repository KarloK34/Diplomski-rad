// ---------------------------------------------------------------------------
// Reason codes
// ---------------------------------------------------------------------------

/// No samples were provided for cadence estimation.
const String emptyCadenceSignalReason = 'empty_signal';

/// The sample timestamps are not strictly increasing.
const String invalidCadenceTimestampsReason = 'invalid_timestamps';

/// The signal is shorter than the app-level cadence gate.
const String cadenceSignalTooShortReason = 'signal_too_short';

/// Peak picking found fewer steps than the app-level cadence gate.
const String tooFewCadencePeaksReason = 'too_few_detected_steps';

/// Autocorrelation did not provide enough periodic evidence.
const String lowCadencePeriodicityReason = 'low_periodicity';

/// Peak-based and period-based cadence estimates differ materially.
const String cadenceEstimatesDisagreeReason = 'cadence_estimates_disagree';

/// Too few repeated events were available for stronger confidence.
const String limitedCadenceEvidenceReason = 'limited_cadence_evidence';

// ---------------------------------------------------------------------------
// Thresholds and defaults
// ---------------------------------------------------------------------------

/// App-level minimum duration before cadence analysis.
///
/// This threshold is a project heuristic and is not a clinically validated
/// minimum recording length.
const Duration defaultCadenceMinimumDuration = Duration(seconds: 2);

/// Low-pass cutoff used to retain the step-related signal component.
///
/// Susi, Renaudin, and Lachapelle, "Motion Mode Recognition and Step Detection
/// Algorithms for Mobile Phone Users", Sensors, 2013,
/// https://doi.org/10.3390/s130201539, use low-pass processing around 3 Hz.
/// This implementation uses a dependency-free fourth-order Butterworth filter
/// rather than the 10th-order design in that paper, so the order is a project
/// adaptation and not a clinically validated design choice.
const double defaultCadenceLowPassCutoffHz = 3;

/// Lower cadence-search bound used by autocorrelation.
///
/// This broad bound is a project heuristic, not a clinically validated limit.
const double defaultCadenceMinimumStepsPerMinute = 60;

/// Upper cadence-search bound used by autocorrelation.
///
/// This broad bound is a project heuristic, not a clinically validated limit.
const double defaultCadenceMaximumStepsPerMinute = 210;

/// Fraction of the dominant period required between accepted peaks.
///
/// This duplicate-peak suppression ratio is a project heuristic. The use of a
/// signal-derived period follows the periodicity-based cadence premise in Wu
/// and Urbanek, "Application of de-shape synchrosqueezing to estimate gait
/// cadence from a single-sensor accelerometer placed in different body
/// locations", Physiological Measurement, 2023,
/// https://doi.org/10.1088/1361-6579/accefe.
const double defaultCadenceMinimumPeakIntervalFraction = 0.75;

/// Adaptive peak threshold multiplier applied to the signal standard deviation.
///
/// Adaptive thresholds follow Susi et al. (2013),
/// https://doi.org/10.3390/s130201539. The value 0.5 is a project heuristic and
/// is not a clinically validated step-detection threshold.
const double defaultCadencePeakThresholdStdMultiplier = 0.5;

/// Preferred minimum autocorrelation for periodic evidence.
///
/// Values just below this gate can still be reported as low-confidence
/// estimates when peak evidence is available. That soft-reporting rule is a
/// project heuristic and is not clinically validated.
const double defaultCadenceMinimumPeriodicity = 0.2;

/// Fraction of the periodicity gate below which cadence is not reported.
///
/// This soft lower bound is a project heuristic: it prevents near-threshold
/// walking segments from disappearing while still rejecting very weakly
/// periodic signals.
const double defaultCadenceReportablePeriodicityFraction = 0.75;

/// Autocorrelation below this value lowers the confidence label.
///
/// This quality threshold is a project heuristic and is not clinically
/// validated.
const double defaultCadenceModeratePeriodicity = 0.35;

/// Autocorrelation required for the high-confidence label.
///
/// This quality threshold is a project heuristic and is not clinically
/// validated.
const double defaultCadenceHighPeriodicity = 0.55;

/// Relative disagreement that lowers confidence in the cadence estimate.
///
/// This comparison threshold is a project heuristic. Comparing peak and
/// periodicity estimates addresses the harmonic ambiguity discussed by Wu and
/// Urbanek (2023), https://doi.org/10.1088/1361-6579/accefe.
const double defaultCadenceMaximumEstimateDisagreement = 0.15;

/// Agreement threshold for promoting long low-periodicity estimates.
///
/// This internal-consistency rule is a project heuristic and is not clinically
/// validated.
const double defaultCadenceStrongEstimateAgreement = 0.05;

/// Minimum accepted peaks for the internal-consistency confidence rule.
///
/// This count is a project heuristic and is not clinically validated.
const int defaultCadenceConsistentEstimateMinimumSteps = 12;

/// Relative strength required to prefer a shorter autocorrelation maximum.
///
/// This harmonic-selection ratio is a project heuristic. Preferring the
/// shorter of similarly supported periods addresses the harmonic ambiguity
/// discussed by Wu and Urbanek (2023),
/// https://doi.org/10.1088/1361-6579/accefe.
const double defaultCadenceComparablePeriodicityRatio = 0.7;

/// App-level minimum number of detected peaks needed to report cadence.
///
/// This threshold is a project heuristic and is not a clinically validated
/// quality rule.
const int defaultCadenceMinimumDetectedSteps = 2;
