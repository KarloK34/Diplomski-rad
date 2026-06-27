import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/ui/ui_event.dart';
import 'package:gait_sense/blocs/ui/ui_state.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/har_model_info.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/services/recording_controller.dart';
import 'package:gait_sense/services/session_limit.dart';
import 'package:gait_sense/services/session_log_repository.dart';

/// Size of the rolling window over which inference-latency percentiles are
/// computed: the most recent [_latencyWindow] predictions (~77 s, at one
/// window per 1.28 s — stride 64 at 50 Hz). A bounded window reports recent
/// conditions rather than a session-cumulative average that hides regressions.
const int _latencyWindow = 60;

/// Orchestrates a recording session on the UI isolate.
///
/// Sits on the UI-isolate side of the foreground-service boundary (hence the
/// name): it drives the [RecordingController] lifecycle, mirrors every incoming
/// prediction into the [SessionLogRepository], and derives the live readouts
/// (elapsed time, prediction count, rolling latency percentiles) the screen
/// renders. The sensing/inference pipeline itself runs in the service isolate.
///
/// When `elapsed` reaches [maxSessionDuration] the bloc emits
/// [UiSessionLimitReached] internally, which triggers the same save flow as a
/// user-initiated stop.
class UiBloc extends Bloc<UiEvent, UiState> {
  /// Creates the bloc around its injected dependencies. The clock, tick
  /// interval, and max session duration are injectable so the elapsed-time
  /// and auto-stop logic are deterministic in tests.
  UiBloc({
    required RecordingController controller,
    required SessionLogRepository repository,
    Map<String, dynamic> modelInfo = harModelInfo,
    DateTime Function() now = DateTime.now,
    Duration tickInterval = const Duration(seconds: 1),
    Duration maxSessionDuration = defaultMaxSessionDuration,
  }) : this._(
         controller,
         repository,
         modelInfo,
         now,
         tickInterval,
         maxSessionDuration,
       );

  UiBloc._(
    this._controller,
    this._repository,
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
  final Map<String, dynamic> _modelInfo;
  final DateTime Function() _now;
  final Duration _tickInterval;

  /// Maximum allowed session duration. Exposed for widget-layer display
  /// (e.g. a countdown or progress indicator).
  final Duration maxSessionDuration;

  StreamSubscription<ActivityPrediction>? _predictionSubscription;
  StreamSubscription<SensorSample>? _sampleSubscription;
  Timer? _ticker;
  DateTime _startedAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Recent inference latencies, capped at _latencyWindow, for the rolling
  // p50/p95 readout. Kept off the state object: only the two computed
  // percentiles are surfaced to the UI.
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
    emit(
      state.copyWith(
        status: RecordingStatus.saved,
        finishedSession: _repository.lastSession,
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

    // Auto-stop when the hard limit is reached. Dispatched as an event so the
    // save flow runs through the normal handler and remains testable.
    if (hasReachedSessionLimit(
      startedAt: _startedAt,
      now: now,
      maxDuration: maxSessionDuration,
    )) {
      add(const UiSessionLimitReached());
    }
  }

  /// Nearest-rank percentile — the inverse-CDF estimator (Definition 1 in
  /// Hyndman & Fan, 1996, https://doi.org/10.2307/2684934). No interpolation
  /// between samples is used: latency is reported in integer milliseconds, so
  /// an interpolated quantile would invent values between measured points.
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
