import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/blocs/ui/ui_bloc.dart';
import 'package:gait_sense/blocs/ui/ui_event.dart';
import 'package:gait_sense/blocs/ui/ui_state.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/repositories/session_log_repository.dart';
import 'package:gait_sense/services/recording_controller.dart';

/// In-memory [RecordingController]: counts lifecycle calls and lets a test feed
/// predictions through [emit]. No platform channels, so it runs on the host VM.
class _FakeController implements RecordingController {
  final StreamController<ActivityPrediction> _controller =
      StreamController<ActivityPrediction>.broadcast();
  final StreamController<SensorSample> _sampleController =
      StreamController<SensorSample>.broadcast();

  int startCount = 0;
  int stopCount = 0;
  int permissionCount = 0;
  FutureOr<void> Function()? onStop;

  void emit(ActivityPrediction prediction) => _controller.add(prediction);

  void emitSample(SensorSample sample) => _sampleController.add(sample);

  @override
  Stream<ActivityPrediction> get predictions => _controller.stream;

  @override
  Stream<SensorSample> get samples => _sampleController.stream;

  @override
  Future<void> requestPermissions() async => permissionCount++;

  @override
  Future<void> start() async => startCount++;

  @override
  Future<void> stop() async {
    stopCount++;
    await onStop?.call();
  }
}

void main() {
  ActivityPrediction prediction(String label, {required int latencyMs}) {
    return ActivityPrediction(
      label: label,
      probabilities: const [0.05, 0.05, 0.6, 0.1, 0.1, 0.1],
      timestamp: DateTime.utc(2026),
      inferenceLatencyMs: latencyMs,
    );
  }

  SensorSample sample(int millisecond) {
    return SensorSample(
      timestamp: DateTime.utc(2026).add(Duration(milliseconds: millisecond)),
      gravityX: 0,
      gravityY: 0,
      gravityZ: 1,
      userAccelerationX: 0.01,
      userAccelerationY: 0.02,
      userAccelerationZ: 0.03,
      rotationRateX: 0.1,
      rotationRateY: 0.2,
      rotationRateZ: 0.3,
    );
  }

  late _FakeController controller;
  late SessionLogRepository repository;
  late Directory tempDir;

  setUp(() {
    controller = _FakeController();
    tempDir = Directory.systemTemp.createTempSync('ui_bloc_test');
    repository = SessionLogRepository(documentsDirectory: () async => tempDir);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  // A long tick interval keeps the periodic timer from emitting UiTicked during
  // tests; elapsed-time handling is driven explicitly via UiTicked instead.
  UiBloc buildBloc({DateTime Function()? now}) {
    return UiBloc(
      controller: controller,
      repository: repository,
      now: now ?? () => DateTime.utc(2026),
      tickInterval: const Duration(hours: 1),
    );
  }

  test(
    'start requests permissions, starts the service, opens a session',
    () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const UiRecordingStarted());
      final state = await bloc.stream.firstWhere(
        (s) => s.status == RecordingStatus.recording,
      );

      expect(controller.permissionCount, 1);
      expect(controller.startCount, 1);
      expect(state.predictionCount, 0);
      expect(repository.count, 0);
    },
  );

  test(
    'appends each prediction and updates the rolling latency percentiles',
    () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const UiRecordingStarted());
      await bloc.stream.firstWhere(
        (s) => s.status == RecordingStatus.recording,
      );

      controller
        ..emit(prediction('wlk', latencyMs: 2))
        ..emit(prediction('wlk', latencyMs: 10));
      final state = await bloc.stream.firstWhere((s) => s.predictionCount == 2);

      expect(repository.count, 2);
      expect(state.latest?.label, 'wlk');
      // Nearest-rank over [2, 10]: p50 -> ceil(0.5*2)=1 -> index 0 -> 2;
      // p95 -> ceil(0.95*2)=2 -> index 1 -> 10.
      expect(state.latencyP50Ms, 2);
      expect(state.latencyP95Ms, 10);
    },
  );

  test('appends raw IMU samples without changing prediction count', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(const UiRecordingStarted());
    await bloc.stream.firstWhere((s) => s.status == RecordingStatus.recording);

    controller
      ..emitSample(sample(20))
      ..emitSample(sample(40));
    await Future<void>.delayed(Duration.zero);

    expect(repository.sampleCount, 2);
    expect(repository.rawSamples.first, sample(20));
    expect(repository.count, 0);
  });

  test('tick recomputes elapsed time from the injected clock', () async {
    var clock = DateTime.utc(2026);
    final bloc = buildBloc(now: () => clock);
    addTearDown(bloc.close);

    bloc.add(const UiRecordingStarted());
    await bloc.stream.firstWhere((s) => s.status == RecordingStatus.recording);

    clock = DateTime.utc(2026, 1, 1, 0, 0, 5);
    bloc.add(const UiTicked());
    final state = await bloc.stream.firstWhere(
      (s) => s.elapsed == const Duration(seconds: 5),
    );

    expect(state.elapsed, const Duration(seconds: 5));
  });

  test('stop saves the session and exposes it on the state', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(const UiRecordingStarted());
    await bloc.stream.firstWhere((s) => s.status == RecordingStatus.recording);
    controller.emitSample(sample(20));
    await Future<void>.delayed(Duration.zero);
    controller.emit(prediction('sit', latencyMs: 3));
    await bloc.stream.firstWhere((s) => s.predictionCount == 1);

    bloc.add(const UiRecordingStopped());
    final state = await bloc.stream.firstWhere(
      (s) => s.status == RecordingStatus.saved,
    );

    expect(controller.stopCount, 1);
    expect(state.finishedSession, isNotNull);
    expect(state.finishedSession!.predictions, hasLength(1));
    expect(state.finishedSession!.rawSamples, hasLength(1));
    expect(repository.lastSession, isNotNull);
  });

  test(
    'stop logs late prediction without updating live prediction count',
    () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const UiRecordingStarted());
      await bloc.stream.firstWhere(
        (s) => s.status == RecordingStatus.recording,
      );

      controller.onStop = () {
        controller
          ..emitSample(sample(40))
          ..emit(prediction('wlk', latencyMs: 5));
      };

      bloc.add(const UiRecordingStopped());
      final state = await bloc.stream.firstWhere(
        (s) => s.status == RecordingStatus.saved,
      );

      expect(state.finishedSession, isNotNull);
      expect(state.finishedSession!.rawSamples, [sample(40)]);
      expect(state.finishedSession!.predictions, [
        prediction('wlk', latencyMs: 5),
      ]);
      expect(state.predictionCount, 0);
    },
  );

  test('reset returns to the idle state after a session is saved', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(const UiRecordingStarted());
    await bloc.stream.firstWhere((s) => s.status == RecordingStatus.recording);
    bloc.add(const UiRecordingStopped());
    await bloc.stream.firstWhere((s) => s.status == RecordingStatus.saved);

    bloc.add(const UiReset());
    final state = await bloc.stream.firstWhere(
      (s) => s.status == RecordingStatus.idle,
    );

    expect(state.finishedSession, isNull);
    expect(state.predictionCount, 0);
  });

  group('session duration limit', () {
    test('auto-stops when elapsed reaches maxSessionDuration', () async {
      var clock = DateTime.utc(2026);
      final bloc = UiBloc(
        controller: controller,
        repository: repository,
        now: () => clock,
        tickInterval: const Duration(hours: 1),
        maxSessionDuration: const Duration(minutes: 5),
      );
      addTearDown(bloc.close);

      bloc.add(const UiRecordingStarted());
      await bloc.stream.firstWhere(
        (s) => s.status == RecordingStatus.recording,
      );

      // Advance clock past the limit and fire a tick.
      clock = DateTime.utc(2026, 1, 1, 0, 5, 1);
      bloc.add(const UiTicked());

      final state = await bloc.stream.firstWhere(
        (s) => s.status == RecordingStatus.saved,
      );

      expect(state.stoppedByLimit, isTrue);
      expect(controller.stopCount, 1);
      expect(state.finishedSession, isNotNull);
    });

    test('stoppedByLimit is false for a user-initiated stop', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const UiRecordingStarted());
      await bloc.stream.firstWhere(
        (s) => s.status == RecordingStatus.recording,
      );
      bloc.add(const UiRecordingStopped());

      final state = await bloc.stream.firstWhere(
        (s) => s.status == RecordingStatus.saved,
      );

      expect(state.stoppedByLimit, isFalse);
    });

    test('does not auto-stop before the limit is reached', () async {
      var clock = DateTime.utc(2026);
      final bloc = UiBloc(
        controller: controller,
        repository: repository,
        now: () => clock,
        tickInterval: const Duration(hours: 1),
        maxSessionDuration: const Duration(minutes: 5),
      );
      addTearDown(bloc.close);

      bloc.add(const UiRecordingStarted());
      await bloc.stream.firstWhere(
        (s) => s.status == RecordingStatus.recording,
      );

      // Advance clock to just under the limit.
      clock = DateTime.utc(2026, 1, 1, 0, 4, 59);
      bloc.add(const UiTicked());
      await bloc.stream.firstWhere(
        (s) => s.elapsed == const Duration(minutes: 4, seconds: 59),
      );

      expect(controller.stopCount, 0);
      expect(bloc.state.status, RecordingStatus.recording);
    });

    test('ignores a second limit event if already saving', () async {
      var clock = DateTime.utc(2026);
      final bloc = UiBloc(
        controller: controller,
        repository: repository,
        now: () => clock,
        tickInterval: const Duration(hours: 1),
        maxSessionDuration: const Duration(minutes: 5),
      );
      addTearDown(bloc.close);

      bloc.add(const UiRecordingStarted());
      await bloc.stream.firstWhere(
        (s) => s.status == RecordingStatus.recording,
      );

      clock = DateTime.utc(2026, 1, 1, 0, 5, 1);
      // Fire two ticks past the limit in quick succession.
      bloc
        ..add(const UiTicked())
        ..add(const UiTicked());

      final state = await bloc.stream.firstWhere(
        (s) => s.status == RecordingStatus.saved,
      );

      // The service must be stopped exactly once despite two limit events.
      expect(controller.stopCount, 1);
      expect(state.stoppedByLimit, isTrue);
    });
  });
}
