import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_event.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_state.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/har_model_info.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/repositories/session_log_repository.dart';
import 'package:gait_sense/repositories/session_summary_repository.dart';
import 'package:gait_sense/services/latency_tracker.dart';
import 'package:gait_sense/services/recording_controller.dart';
import 'package:gait_sense/services/sensor_readiness_probe.dart';
import 'package:gait_sense/services/session_limit.dart';

/// Orchestrates a recording session on the UI isolate; the sensing/inference
/// pipeline itself runs in the service isolate.
///
/// Reaching [maxSessionDuration] emits [RecordingSessionLimitReached]
/// internally, so auto-stop reuses the same save flow as a user-initiated
/// stop.
class RecordingSessionBloc
    extends Bloc<RecordingSessionEvent, RecordingSessionState> {
  /// Clock, tick interval, and max duration are injectable so elapsed-time
  /// and auto-stop logic are deterministic in tests.
  RecordingSessionBloc({
    required RecordingController controller,
    required SessionLogRepository repository,
    SessionSummaryRepository? summaryRepository,
    Map<String, dynamic> modelInfo = harModelInfo,
    DateTime Function() now = DateTime.now,
    Duration tickInterval = const Duration(seconds: 1),
    Duration maxSessionDuration = defaultMaxSessionDuration,
    Duration preparationDuration = defaultPreparationDuration,
  }) : this._(
         controller,
         repository,
         summaryRepository,
         modelInfo,
         now,
         tickInterval,
         maxSessionDuration,
         preparationDuration,
       );

  RecordingSessionBloc._(
    this._controller,
    this._repository,
    this._summaryRepository,
    this._modelInfo,
    this._now,
    this._tickInterval,
    this.maxSessionDuration,
    this.preparationDuration,
  ) : super(const RecordingSessionState.initial()) {
    on<RecordingSessionStarted>(_onStarted);
    on<RecordingSessionCountdownTicked>(_onCountdownTicked);
    on<RecordingSessionCountdownCancelled>(_onCountdownCancelled);
    on<RecordingSessionStopped>(_onStopped);
    on<RecordingSessionLimitReached>(_onLimitReached);
    on<RecordingSessionReset>(_onReset);
    on<RecordingSessionPredictionReceived>(_onPredictionReceived);
    on<RecordingSessionTicked>(_onTicked);
  }

  final RecordingController _controller;
  final SessionLogRepository _repository;
  final SessionSummaryRepository? _summaryRepository;
  final Map<String, dynamic> _modelInfo;
  final DateTime Function() _now;
  final Duration _tickInterval;

  /// Maximum allowed session duration, exposed for widget-layer display.
  final Duration maxSessionDuration;

  /// Length of the pre-recording countdown, exposed for widget-layer display.
  final Duration preparationDuration;

  late final SensorReadinessProbe _probe = SensorReadinessProbe(_controller);
  final LatencyTracker _latencyTracker = LatencyTracker();

  StreamSubscription<ActivityPrediction>? _predictionSubscription;
  StreamSubscription<SensorSample>? _sampleSubscription;
  Timer? _ticker;
  Timer? _countdownTicker;
  DateTime _startedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _countdownRemaining = Duration.zero;

  /// Guards the preparing->recording/idle transition against the tick-vs-
  /// cancel race: flutter_bloc's default transformer gives
  /// [RecordingSessionCountdownTicked] and [RecordingSessionCountdownCancelled]
  /// independent async pipelines, so both can pass their `status == preparing`
  /// check before either emits. Whichever handler flips this flag first (in a
  /// synchronous check-then-set with no intervening await) wins; the other
  /// bails out after its own `_probe.disarm()` await instead of also
  /// committing/stopping and emitting a conflicting state.
  bool _countdownSettled = false;

  /// Arms the sensor-readiness probe and starts the pre-recording countdown.
  ///
  /// Doesn't yet start session bookkeeping — that happens in
  /// [_onCountdownTicked] once the countdown elapses, so samples captured
  /// while the phone is still being pocketed never enter the recorded
  /// session. The probe is armed immediately (not at countdown end) so it
  /// has the whole countdown window to prove the sensors actually work,
  /// which is exactly the [RecordingStatus.unavailable] signal this reuses
  /// the countdown for.
  Future<void> _onStarted(
    RecordingSessionStarted event,
    Emitter<RecordingSessionState> emit,
  ) async {
    if (state.status == RecordingStatus.preparing ||
        state.status == RecordingStatus.recording) {
      return;
    }

    try {
      await _probe.arm();
    } on Object catch (error, stackTrace) {
      debugPrint('Sensor readiness probe failed to arm: $error\n$stackTrace');
      await _probe.disarm();
      await _controller.stop();
      emit(
        const RecordingSessionState.initial().copyWith(
          status: RecordingStatus.unavailable,
        ),
      );
      return;
    }

    _countdownRemaining = preparationDuration;
    _countdownSettled = false;
    _countdownTicker?.cancel();
    _countdownTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const RecordingSessionCountdownTicked()),
    );

    emit(
      const RecordingSessionState.initial().copyWith(
        status: RecordingStatus.preparing,
        countdownSecondsRemaining: _countdownRemaining.inSeconds,
      ),
    );
  }

  Future<void> _onCountdownTicked(
    RecordingSessionCountdownTicked event,
    Emitter<RecordingSessionState> emit,
  ) async {
    if (state.status != RecordingStatus.preparing) return;
    _countdownRemaining -= const Duration(seconds: 1);

    if (_countdownRemaining > Duration.zero) {
      emit(
        state.copyWith(
          countdownSecondsRemaining: _countdownRemaining.inSeconds,
        ),
      );
      return;
    }

    _countdownTicker?.cancel();
    _countdownTicker = null;

    if (!_probe.isReady) {
      await _probe.disarm();
      if (_countdownSettled) return;
      _countdownSettled = true;
      await _controller.stop();
      emit(state.copyWith(status: RecordingStatus.unavailable));
      return;
    }

    await _probe.disarm();
    if (_countdownSettled) return;
    _countdownSettled = true;
    _controller.commitRecording();
    _startedAt = _now();
    _latencyTracker.reset();
    _repository.startSession(startedAt: _startedAt, modelInfo: _modelInfo);

    await _predictionSubscription?.cancel();
    _predictionSubscription = _controller.predictions.listen(
      (prediction) => add(RecordingSessionPredictionReceived(prediction)),
    );
    _sampleSubscription = _controller.samples.listen(_repository.appendSample);
    _ticker?.cancel();
    _ticker = Timer.periodic(
      _tickInterval,
      (_) => add(const RecordingSessionTicked()),
    );

    emit(
      const RecordingSessionState.initial().copyWith(
        status: RecordingStatus.recording,
      ),
    );
  }

  Future<void> _onCountdownCancelled(
    RecordingSessionCountdownCancelled event,
    Emitter<RecordingSessionState> emit,
  ) async {
    if (state.status != RecordingStatus.preparing) return;
    _countdownTicker?.cancel();
    _countdownTicker = null;

    await _probe.disarm();
    if (_countdownSettled) return;
    _countdownSettled = true;

    await _controller.stop();

    emit(const RecordingSessionState.initial());
  }

  Future<void> _onStopped(
    RecordingSessionStopped event,
    Emitter<RecordingSessionState> emit,
  ) async {
    await _stopSession(emit, stoppedByLimit: false);
  }

  Future<void> _onLimitReached(
    RecordingSessionLimitReached event,
    Emitter<RecordingSessionState> emit,
  ) async {
    await _stopSession(emit, stoppedByLimit: true);
  }

  /// Common teardown path shared by user-initiated and limit-triggered stops.
  Future<void> _stopSession(
    Emitter<RecordingSessionState> emit, {
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

  void _onReset(
    RecordingSessionReset event,
    Emitter<RecordingSessionState> emit,
  ) {
    // Ignore a reset mid-recording: a running session must be stopped first.
    if (state.status == RecordingStatus.recording) return;
    emit(const RecordingSessionState.initial());
  }

  void _onPredictionReceived(
    RecordingSessionPredictionReceived event,
    Emitter<RecordingSessionState> emit,
  ) {
    final isRecording = state.status == RecordingStatus.recording;
    final isSaving = state.status == RecordingStatus.saving;
    if (!isRecording && !isSaving) return;

    _repository.append(event.prediction);
    if (!isRecording) return;

    final percentiles = _latencyTracker.add(
      event.prediction.inferenceLatencyMs,
    );

    emit(
      state.copyWith(
        predictionCount: state.predictionCount + 1,
        latest: event.prediction,
        latencyP50Ms: percentiles.p50,
        latencyP95Ms: percentiles.p95,
      ),
    );
  }

  void _onTicked(
    RecordingSessionTicked event,
    Emitter<RecordingSessionState> emit,
  ) {
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
      add(const RecordingSessionLimitReached());
    }
  }

  @override
  Future<void> close() async {
    await _probe.disarm();
    await _predictionSubscription?.cancel();
    await _sampleSubscription?.cancel();
    _ticker?.cancel();
    _countdownTicker?.cancel();
    return super.close();
  }
}
