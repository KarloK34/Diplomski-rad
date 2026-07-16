import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/har_model_info.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/screens/session_summary/session_summary_computation.dart';

void main() {
  ActivityPrediction prediction(String label, int second) => ActivityPrediction(
    label: label,
    probabilities: const [0.1, 0.1, 0.6, 0.1, 0.05, 0.05],
    timestamp: DateTime.utc(2026, 1, 1, 12, 0, second),
    inferenceLatencyMs: 20,
    endSampleIndex: second * 50,
  );

  SessionLog buildSession(List<ActivityPrediction> predictions) => SessionLog(
    startedAt: DateTime.utc(2026, 1, 1, 12),
    stoppedAt: DateTime.utc(2026, 1, 1, 12, 5),
    modelInfo: harModelInfo,
    predictions: predictions,
  );

  SessionSummaryRecord recordFor(SessionLog session, {double? heightCm}) {
    final data = computeSessionSummaryData(
      SessionSummaryInput(session: session, userHeightCm: heightCm),
    );
    return SessionSummaryRecord.fromComputed(
      session: session,
      totals: data.totals,
      timeline: data.timeline,
      quality: data.quality,
      heightCm: heightCm,
    );
  }

  group('SessionSummaryRecord', () {
    test('fromComputed carries the computed summary and metadata', () {
      final session = buildSession([
        prediction('wlk', 1),
        prediction('wlk', 2),
        prediction('std', 3),
        prediction('wlk', 4),
      ]);
      final data = computeSessionSummaryData(
        SessionSummaryInput(session: session, userHeightCm: 175),
      );

      final record = SessionSummaryRecord.fromComputed(
        session: session,
        totals: data.totals,
        timeline: data.timeline,
        quality: data.quality,
        heightCm: 175,
      );

      expect(record.predictionCount, 4);
      expect(record.heightCmAtRecording, 175);
      expect(record.id, session.startedAt.toIso8601String());
      expect(record.classTotals, data.totals);
      expect(record.timeline, data.timeline);
      expect(record.quality, data.quality);
    });

    test('survives a JSON round-trip', () {
      final record = recordFor(
        buildSession([
          prediction('wlk', 1),
          prediction('std', 2),
          prediction('wlk', 3),
        ]),
        heightCm: 180,
      );

      final json = record.toJson();
      final decoded = SessionSummaryRecord.fromJson(json);

      expect(decoded.toJson(), json);
      expect(decoded, record);
    });

    test('round-trips an empty session', () {
      final record = recordFor(buildSession(const []));

      final decoded = SessionSummaryRecord.fromJson(record.toJson());

      expect(decoded.predictionCount, 0);
      expect(decoded.classTotals, isEmpty);
      expect(decoded, record);
    });
  });
}
