import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/services/recording_controller.dart';
import 'package:gait_sense/services/sensor_readiness_probe.dart';

/// In-memory [RecordingController]: counts lifecycle calls and lets a test
/// feed samples through [emitSample]. No platform channels, so it runs on
/// the host VM.
class _FakeController implements RecordingController {
  final StreamController<SensorSample> _samples =
      StreamController<SensorSample>.broadcast();

  int permissionCount = 0;
  int startCount = 0;
  int stopCount = 0;

  void emitSample() {
    _samples.add(
      SensorSample(
        timestamp: DateTime.utc(2026),
        gravityX: 0,
        gravityY: 0,
        gravityZ: 1,
        userAccelerationX: 0,
        userAccelerationY: 0,
        userAccelerationZ: 0,
        rotationRateX: 0,
        rotationRateY: 0,
        rotationRateZ: 0,
      ),
    );
  }

  @override
  Stream<ActivityPrediction> get predictions => const Stream.empty();

  @override
  Stream<SensorSample> get samples => _samples.stream;

  @override
  Future<void> requestPermissions() async => permissionCount++;

  @override
  Future<void> start() async => startCount++;

  @override
  void commitRecording() {}

  @override
  Future<void> stop() async => stopCount++;
}

void main() {
  late _FakeController controller;
  late SensorReadinessProbe probe;

  setUp(() {
    controller = _FakeController();
    probe = SensorReadinessProbe(controller);
  });

  test('arm requests permissions and starts the controller', () async {
    await probe.arm();

    expect(controller.permissionCount, 1);
    expect(controller.startCount, 1);
    expect(probe.isReady, isFalse);
  });

  test('isReady flips true once a sample arrives after arm', () async {
    await probe.arm();
    controller.emitSample();
    await Future<void>.delayed(Duration.zero);

    expect(probe.isReady, isTrue);
  });

  test('re-arming resets readiness for a fresh countdown', () async {
    await probe.arm();
    controller.emitSample();
    await Future<void>.delayed(Duration.zero);
    expect(probe.isReady, isTrue);

    await probe.arm();

    expect(probe.isReady, isFalse);
  });

  test('disarm stops watching for further samples', () async {
    await probe.arm();
    await probe.disarm();

    controller.emitSample();
    await Future<void>.delayed(Duration.zero);

    expect(probe.isReady, isFalse);
  });
}
