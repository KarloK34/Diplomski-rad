import 'dart:convert';
import 'dart:io';

import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:path_provider/path_provider.dart';

/// Owns the active session's prediction buffer and persists a finished session
/// to a single JSON file under `<documents>/sessions/`.
///
/// Predictions accumulate in a mutable in-memory list rather than rebuilding an
/// immutable [SessionLog] per window. At one prediction per 1.28 s (128-sample
/// window, stride 64, 50 Hz) a 10-minute session holds ~470 predictions, each a
/// label + 6 doubles + a timestamp + an int — on the order of tens of KB, so an
/// unbounded list is adequate for realistic session lengths.
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

  SessionLog? _lastSession;

  /// The most recently finished session, exposed to the summary screen.
  SessionLog? get lastSession => _lastSession;

  /// Number of predictions buffered in the active session.
  int get count => _predictions.length;

  /// Unmodifiable view of the predictions buffered so far.
  List<ActivityPrediction> get predictions => List.unmodifiable(_predictions);

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
  }

  /// Appends one prediction to the active session.
  void append(ActivityPrediction prediction) {
    _predictions.add(prediction);
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
