import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/ui/ui_event.dart';
import 'package:gait_sense/blocs/ui/ui_state.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/har_model_info.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/repositories/session_log_repository.dart';
import 'package:gait_sense/repositories/session_summary_repository.dart';
import 'package:gait_sense/services/recording_controller.dart';
import 'package:gait_sense/services/session_limit.dart';

/// Rolling window size for latency percentiles — bounded so recent
/// regressions aren't hidden by a session-cumulative average.
const int _latencyWindow = 60;

/// Orchestrates a recording session on the UI isolate; the sensing/inference
/// pipeline itself runs in the service isolate.
///
/// Reaching [maxSessionDuration] emits [UiSessionLimitReached] internally, so
/// auto-stop reuses the same save flow as a user-initiated stop.
class UiBloc extends Bloc<UiEvent, UiState> {
  /// Clock, tick interval, and max duration are injectable so elapsed-time
  /// and auto-stop logic are deterministic in tests.
  UiBloc({
    required RecordingController controller,
    required SessionLogRepository repository,
    SessionSummaryRepository? summaryRepository,
    Map<String, dynamic> modelInfo = harModelInfo,
    DateTime Function() now = DateTime.now,
    Duration tickInterval = const Duration(seconds: 1),
    Duration maxSessionDuration = defaultMaxSessionDuration,
  }) : this._(
         controller,
         repository,
         summaryRepository,
         modelInfo,
         now,
         tickInterval,
         maxSessionDuration,
       );

  UiBloc._(
    this._controller,
    this._repository,
    this._summaryRepository,
    this._modelInfo,
    this._now,
    this._tickInterval,
    this.maxSessionDuration,
  ) : super(const UiState.initial()) {
    on<UiRecordingStarted>(_onStarted);
    on<UiRecordingStopped>(_onStopped);
    on<UiSessionLimitReached>(_onLimitReached);
    on<UiReset>(_onReset);
    on<UiPredictionReceived>(_onPredictionReceived);
    on<UiTicked>(_onTicked);
  }

  final RecordingController _controller;
  final SessionLogRepository _repository;
  final SessionSummaryRepository? _summaryRepository;
  final Map<String, dynamic> _modelInfo;
  final DateTime Function() _now;
  final Duration _tickInterval;

  /// Maximum allowed session duration, exposed for widget-layer display.
  final Duration maxSessionDuration;

  StreamSubscription<ActivityPrediction>? _predictionSubscription;
  StreamSubscription<SensorSample>? _sampleSubscription;
  Timer? _ticker;
  DateTime _startedAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Recent latencies for the rolling p50/p95 readout — kept off the state
  // object since only the computed percentiles are surfaced.
  final List<int> _latencies = [];

  Future<void> _onStarted(
    UiRecordingStarted event,
    Emitter<UiState> emit,
  ) async {
    if (state.status == RecordingStatus.recording) return;
    _startedAt = _now();
    _latencies.clear();

    await _controller.requestPermissions();
    _repository.startSession(startedAt: _startedAt, modelInfo: _modelInfo);

    await _predictionSubscription?.cancel();
    await _sampleSubscription?.cancel();
    _predictionSubscription = _controller.predictions.listen(
      (prediction) => add(UiPredictionReceived(prediction)),
    );
    _sampleSubscription = _controller.samples.listen(_repository.appendSample);
    await _controller.start();
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickInterval, (_) => add(const UiTicked()));

    emit(const UiState.initial().copyWith(status: RecordingStatus.recording));
  }

  Future<void> _onStopped(
    UiRecordingStopped event,
    Emitter<UiState> emit,
  ) async {
    await _stopSession(emit, stoppedByLimit: false);
  }

  Future<void> _onLimitReached(
    UiSessionLimitReached event,
    Emitter<UiState> emit,
  ) async {
    await _stopSession(emit, stoppedByLimit: true);
  }

  /// Common teardown path shared by user-initiated and limit-triggered stops.
  Future<void> _stopSession(
    Emitter<UiState> emit, {
    required bool stoppedByLimit,
  }) async {
    if (state.status != RecordingStatus.recording) return;
    _ticker?.cancel();
    _ticker = null;

    emit(state.copyWith(status: RecordingStatus.saving));
    await _controller.stop();
    await Future<void>.delayed(Duration.zero);

    await _predictionSubscription?.cancel();
    _predictionSubscription = null;
    await _sampleSubscription?.cancel();
    _sampleSubscription = null;

    await _repository.finishAndSave(stoppedAt: _now());
    final savedSession = _repository.lastSession;
    // Fire-and-forget: local save is the offline-safe path and must not block
    // on network. Firestore retries queued offline writes itself, so a
    // logged error here means the sync failed for another reason.
    if (savedSession != null) {
      unawaited(
        _summaryRepository
            ?.syncSession(savedSession)
            .catchError(
              (Object error) => debugPrint('Session sync failed: $error'),
            ),
      );
    }
    emit(
      state.copyWith(
        status: RecordingStatus.saved,
        finishedSession: savedSession,
        stoppedByLimit: stoppedByLimit,
      ),
    );
  }

  void _onReset(UiReset event, Emitter<UiState> emit) {
    // Ignore a reset mid-recording: a running session must be stopped first.
    if (state.status == RecordingStatus.recording) return;
    emit(const UiState.initial());
  }

  void _onPredictionReceived(
    UiPredictionReceived event,
    Emitter<UiState> emit,
  ) {
    final isRecording = state.status == RecordingStatus.recording;
    final isSaving = state.status == RecordingStatus.saving;
    if (!isRecording && !isSaving) return;

    _repository.append(event.prediction);
    if (!isRecording) return;

    _latencies.add(event.prediction.inferenceLatencyMs);
    if (_latencies.length > _latencyWindow) {
      _latencies.removeRange(0, _latencies.length - _latencyWindow);
    }
    final sorted = List<int>.of(_latencies)..sort();

    emit(
      state.copyWith(
        predictionCount: state.predictionCount + 1,
        latest: event.prediction,
        latencyP50Ms: _percentile(sorted, 50),
        latencyP95Ms: _percentile(sorted, 95),
      ),
    );
  }

  void _onTicked(UiTicked event, Emitter<UiState> emit) {
    if (state.status != RecordingStatus.recording) return;
    final now = _now();
    final elapsed = now.difference(_startedAt);
    emit(state.copyWith(elapsed: elapsed));

    // Dispatched as an event, not called directly, so auto-stop stays testable.
    if (hasReachedSessionLimit(
      startedAt: _startedAt,
      now: now,
      maxDuration: maxSessionDuration,
    )) {
      add(const UiSessionLimitReached());
    }
  }

  /// Nearest-rank percentile (Hyndman & Fan, 1996, Definition 1,
  /// https://doi.org/10.2307/2684934) — no interpolation, since latency is
  /// reported in integer milliseconds.
  static int _percentile(List<int> sortedAscending, double p) {
    if (sortedAscending.isEmpty) return 0;
    final rank = (p / 100 * sortedAscending.length).ceil();
    var index = rank - 1;
    if (index < 0) index = 0;
    if (index > sortedAscending.length - 1) index = sortedAscending.length - 1;
    return sortedAscending[index];
  }

  @override
  Future<void> close() async {
    await _predictionSubscription?.cancel();
    await _sampleSubscription?.cancel();
    _ticker?.cancel();
    return super.close();
  }
}
