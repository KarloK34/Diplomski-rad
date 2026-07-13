import 'dart:convert';
import 'dart:io';

import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:path_provider/path_provider.dart';

/// Owns the active session's prediction buffer and persists a finished session
/// to a single JSON file under `<documents>/sessions/`.
///
/// Predictions and raw IMU samples accumulate in mutable in-memory lists rather
/// than rebuilding an immutable [SessionLog] on each event. Raw samples are
/// retained because acceleration-derived gait parameters require a timestamped
/// signal (Zijlstra & Hof, "Assessment of spatio-temporal gait parameters from
/// trunk accelerations during human walking", Gait & Posture, 2003,
/// https://doi.org/10.1016/S0966-6362(02)00190-X); the decision to keep the
/// full raw stream in this app log is project-specific and not a clinical
/// validation decision.
class SessionLogRepository {
  /// [documentsDirectory] is injectable so the file-writing logic is unit
  /// testable: [getApplicationDocumentsDirectory] resolves through a platform
  /// channel that does not exist in the host `flutter test` VM, so tests pass a
  /// temporary directory instead of the real documents directory.
  SessionLogRepository({
    Future<Directory> Function()? documentsDirectory,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  DateTime? _startedAt;
  String? _deviceId;
  Map<String, dynamic> _modelInfo = const {};
  final List<ActivityPrediction> _predictions = [];
  final List<SensorSample> _rawSamples = [];

  SessionLog? _lastSession;

  /// The most recently finished session, exposed to the summary screen.
  SessionLog? get lastSession => _lastSession;

  /// Number of predictions buffered in the active session.
  int get count => _predictions.length;

  /// Number of raw IMU samples buffered in the active session.
  int get sampleCount => _rawSamples.length;

  /// Unmodifiable view of the predictions buffered so far.
  List<ActivityPrediction> get predictions => List.unmodifiable(_predictions);

  /// Unmodifiable view of the raw IMU samples buffered so far.
  List<SensorSample> get rawSamples => List.unmodifiable(_rawSamples);

  /// Begins a new session, clearing any buffered predictions.
  void startSession({
    required DateTime startedAt,
    required Map<String, dynamic> modelInfo,
    String? deviceId,
  }) {
    _startedAt = startedAt;
    _modelInfo = modelInfo;
    _deviceId = deviceId;
    _predictions.clear();
    _rawSamples.clear();
  }

  /// Appends one prediction to the active session.
  void append(ActivityPrediction prediction) {
    _predictions.add(prediction);
  }

  /// Appends one raw IMU sample to the active session.
  void appendSample(SensorSample sample) {
    _rawSamples.add(sample);
  }

  /// Finalizes the session, writes it to
  /// `<documents>/sessions/session_<timestamp>.json`, and returns the file.
  ///
  /// Throws [StateError] if called before [startSession].
  Future<File> finishAndSave({required DateTime stoppedAt}) async {
    final startedAt = _startedAt;
    if (startedAt == null) {
      throw StateError('finishAndSave called before startSession');
    }

    final session = SessionLog(
      startedAt: startedAt,
      stoppedAt: stoppedAt,
      deviceId: _deviceId,
      modelInfo: _modelInfo,
      rawSamples: List.of(_rawSamples),
      predictions: List.of(_predictions),
    );
    _lastSession = session;

    final documents = await _documentsDirectory();
    final sessionsDir = Directory('${documents.path}/sessions');
    if (!sessionsDir.existsSync()) {
      sessionsDir.createSync(recursive: true);
    }

    // Colons are not valid in filenames on every target filesystem, so the
    // ISO-8601 timestamp is sanitized to `-` before being used as a filename.
    final stamp = startedAt.toIso8601String().replaceAll(':', '-');
    final file = File('${sessionsDir.path}/session_$stamp.json');
    await file.writeAsString(jsonEncode(session.toJson()));
    return file;
  }
}
