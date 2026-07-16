import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:path_provider/path_provider.dart';

/// Decodes one draft's raw JSON into a [SessionLog], or the parse error's
/// [Object.toString] on failure — run via [compute] since a draft holds
/// every raw IMU sample from its recording, so decoding several at once can
/// take more than a few ms.
Object _tryParseSessionLog(String raw) {
  try {
    return SessionLog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } on Object catch (error) {
    return error.toString();
  }
}

/// Batch entry point for [compute]: parses every draft's contents in one
/// spawned isolate rather than paying isolate-spawn overhead per file.
List<Object> _parsePendingDrafts(List<String> contents) => [
  for (final raw in contents) _tryParseSessionLog(raw),
];

/// Entry point for [compute]: parses a single imported session's contents.
SessionLog _parseImportedSessionLog(String contents) =>
    SessionLog.fromJson(jsonDecode(contents) as Map<String, dynamic>);

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

  /// Finalizes the session from the buffered predictions and raw samples and
  /// returns it.
  ///
  /// Persisting is deferred to [saveToDisk] so the summary screen can offer an
  /// explicit save (and a back-to-discard).
  ///
  /// Throws [StateError] if called before [startSession].
  SessionLog finish({required DateTime stoppedAt}) {
    final startedAt = _startedAt;
    if (startedAt == null) {
      throw StateError('finish called before startSession');
    }

    final session = SessionLog(
      startedAt: startedAt,
      stoppedAt: stoppedAt,
      deviceId: _deviceId,
      modelInfo: _modelInfo,
      rawSamples: List.of(_rawSamples),
      predictions: List.of(_predictions),
    );
    return session;
  }

  /// Writes [session] to `<documents>/sessions/session_<timestamp>.json` and
  /// returns the file. Called when the user saves.
  Future<File> saveToDisk(SessionLog session) async {
    final documents = await _documentsDirectory();
    final sessionsDir = Directory('${documents.path}/sessions');
    if (!sessionsDir.existsSync()) {
      sessionsDir.createSync(recursive: true);
    }

    final file = File('${sessionsDir.path}/${_stampFilename(session)}');
    await file.writeAsString(jsonEncode(session.toJson()));
    return file;
  }

  /// Writes [session] as a recoverable draft under
  /// `<documents>/sessions/pending/`, before the user has chosen to save or
  /// discard it — so an app kill between [finish] and that decision leaves
  /// something on disk to recover on next launch instead of losing the
  /// session outright.
  ///
  /// Written to a temp file and renamed into place: [File.rename] is atomic
  /// on a given filesystem, so [listPendingDrafts] never trips over a draft
  /// half-written by a process that died mid-write.
  Future<File> savePendingDraft(SessionLog session) async {
    final pendingDir = await _pendingDirectory();
    final file = File('${pendingDir.path}/${_stampFilename(session)}');
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(jsonEncode(session.toJson()));
    return tempFile.rename(file.path);
  }

  /// Deletes the pending draft for [session], if one exists.
  ///
  /// Safe to call unconditionally: called both when the user saves (the
  /// draft is superseded by [saveToDisk]'s output) and when they discard (the
  /// draft is the only copy, so this is the actual deletion).
  Future<void> deletePendingDraft(SessionLog session) async {
    final pendingDir = await _pendingDirectory();
    final file = File('${pendingDir.path}/${_stampFilename(session)}');
    if (file.existsSync()) await file.delete();
  }

  /// Recovers sessions left behind by an app kill between [savePendingDraft]
  /// and the user's save/discard decision.
  ///
  /// A draft that fails to parse has nothing recoverable in it — that can
  /// only happen if the temp-file rename above never completed — so it's
  /// deleted rather than surfaced as a broken recovery entry.
  ///
  /// Called unconditionally at app startup (see `AppDependencies.init`), so a
  /// failure to resolve the documents directory itself is swallowed rather
  /// than thrown — recovery is best-effort and must never block startup.
  Future<List<SessionLog>> listPendingDrafts() async {
    final Directory pendingDir;
    try {
      pendingDir = await _pendingDirectory();
    } on Object catch (error) {
      debugPrint('Could not resolve the pending sessions directory: $error');
      return const [];
    }
    if (!pendingDir.existsSync()) return const [];

    final files = [
      for (final entity in pendingDir.listSync())
        if (entity is File && entity.path.endsWith('.json')) entity,
    ];
    if (files.isEmpty) return const [];

    final contents = await Future.wait(
      files.map((file) => file.readAsString()),
    );
    // Batched into a single isolate spawn rather than one compute() call per
    // file, since spawn overhead would otherwise dominate for a handful of
    // small drafts.
    final parsed = await compute(_parsePendingDrafts, contents);

    final drafts = <SessionLog>[];
    for (var i = 0; i < files.length; i++) {
      final result = parsed[i];
      if (result is SessionLog) {
        drafts.add(result);
        continue;
      }
      debugPrint(
        'Discarding unrecoverable pending session '
        '${files[i].path}: $result',
      );
      await files[i].delete();
    }
    return drafts;
  }

  /// Parses [contents] — the raw text of an exported session JSON file —
  /// into a [SessionLog].
  ///
  /// Used by the debug "import session" flow to load a session recorded
  /// (and exported via [saveToDisk]'s output or the summary screen's export
  /// action) on another run or device, without going through [startSession]
  /// and [finish]. Rethrows [FormatException] from malformed JSON or
  /// [TypeError] from a shape that doesn't match [SessionLog.fromJson] —
  /// the caller reports these to the user rather than treating them as
  /// recoverable.
  ///
  /// Runs off the main isolate via [compute]: an exported session holds
  /// every raw IMU sample from its recording, so decoding it can take more
  /// than a few ms.
  Future<SessionLog> importFromJson(String contents) {
    return compute(_parseImportedSessionLog, contents);
  }

  Future<Directory> _pendingDirectory() async {
    final documents = await _documentsDirectory();
    final dir = Directory('${documents.path}/sessions/pending');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  // Colons are not valid in filenames on every target filesystem, so the
  // ISO-8601 timestamp is sanitized to `-` before being used as a filename.
  String _stampFilename(SessionLog session) {
    final stamp = session.startedAt.toIso8601String().replaceAll(':', '-');
    return 'session_$stamp.json';
  }
}
