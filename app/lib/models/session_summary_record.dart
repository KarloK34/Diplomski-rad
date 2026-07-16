import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/utils/session_summary.dart';
import 'package:gait_sense/utils/session_summary_serialization.dart';

/// The persisted, cloud-synced projection of a finished session.
///
/// Holds the computed summary — per-class totals, the activity timeline, and
/// the quality/gait metrics — but never the raw IMU stream, which stays
/// on-device. Because [SessionQualitySummary] carries only scalar summaries and
/// sample indices (not samples), the whole computed summary serializes well
/// under Firestore's 1 MiB per-document limit and reconstructs exactly, so the
/// detail view renders identically to the post-recording summary on any device.
class SessionSummaryRecord extends Equatable {
  /// Creates a persisted session-summary record.
  const SessionSummaryRecord({
    required this.startedAt,
    required this.stoppedAt,
    required this.duration,
    required this.deviceId,
    required this.predictionCount,
    required this.modelInfo,
    required this.heightCmAtRecording,
    required this.classTotals,
    required this.timeline,
    required this.quality,
    this.schemaVersion = currentSchemaVersion,
  });

  /// Builds a record from the values already computed for the summary screen,
  /// so persistence never recomputes anything.
  factory SessionSummaryRecord.fromComputed({
    required SessionLog session,
    required List<ClassTotal> totals,
    required List<TimelineSegment> timeline,
    required SessionQualitySummary quality,
    double? heightCm,
  }) {
    return SessionSummaryRecord(
      startedAt: session.startedAt,
      stoppedAt: session.stoppedAt,
      duration: sessionDuration(session),
      deviceId: session.deviceId,
      predictionCount: session.predictions.length,
      modelInfo: session.modelInfo,
      heightCmAtRecording: heightCm,
      classTotals: totals,
      timeline: timeline,
      quality: quality,
    );
  }

  /// Decodes a record from its Firestore/JSON representation.
  factory SessionSummaryRecord.fromJson(Map<String, dynamic> json) {
    return SessionSummaryRecord(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      startedAt: DateTime.parse(json['startedAt'] as String),
      stoppedAt: json['stoppedAt'] == null
          ? null
          : DateTime.parse(json['stoppedAt'] as String),
      duration: Duration(milliseconds: (json['durationMs'] as num).toInt()),
      deviceId: json['deviceId'] as String?,
      predictionCount: (json['predictionCount'] as num).toInt(),
      modelInfo: Map<String, dynamic>.from(
        json['modelInfo'] as Map? ?? const {},
      ),
      heightCmAtRecording: (json['heightCmAtRecording'] as num?)?.toDouble(),
      classTotals: [
        for (final total in json['classTotals'] as List? ?? const [])
          classTotalFromJson(total as Map<String, dynamic>),
      ],
      timeline: [
        for (final segment in json['timeline'] as List? ?? const [])
          timelineSegmentFromJson(segment as Map<String, dynamic>),
      ],
      quality: qualitySummaryFromJson(json['quality'] as Map<String, dynamic>),
    );
  }

  /// Bumped when the stored shape changes incompatibly.
  static const int currentSchemaVersion = 1;

  /// Version of the stored document shape.
  final int schemaVersion;

  /// When recording started; also the Firestore document id (see [id]).
  final DateTime startedAt;

  /// When recording stopped, or null for a session that never stopped.
  final DateTime? stoppedAt;

  /// Wall-clock duration as shown on the summary/detail screens.
  final Duration duration;

  /// Recording device identifier, when available.
  final String? deviceId;

  /// Total number of prediction windows in the session.
  final int predictionCount;

  /// Model provenance (channel order + class labels) copied from the session.
  final Map<String, dynamic> modelInfo;

  /// Body height used for the walking-speed estimate, for traceability.
  final double? heightCmAtRecording;

  /// Per-class time totals.
  final List<ClassTotal> classTotals;

  /// Collapsed activity timeline.
  final List<TimelineSegment> timeline;

  /// Quality and gait-analysis metrics.
  final SessionQualitySummary quality;

  /// Stable document id derived from the start time.
  String get id => startedAt.toIso8601String();

  /// Encodes the record for Firestore/JSON storage.
  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'startedAt': startedAt.toIso8601String(),
    'stoppedAt': stoppedAt?.toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'deviceId': deviceId,
    'predictionCount': predictionCount,
    'modelInfo': modelInfo,
    'heightCmAtRecording': heightCmAtRecording,
    'classTotals': [
      for (final total in classTotals) classTotalToJson(total),
    ],
    'timeline': [
      for (final segment in timeline) timelineSegmentToJson(segment),
    ],
    'quality': qualitySummaryToJson(quality),
  };

  @override
  List<Object?> get props => [
    schemaVersion,
    startedAt,
    stoppedAt,
    duration,
    deviceId,
    predictionCount,
    modelInfo,
    heightCmAtRecording,
    classTotals,
    timeline,
    quality,
  ];
}
