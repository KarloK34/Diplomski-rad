import 'dart:async';

import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/utils/sensor_conversion.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Streams IMU samples at a fixed rate in the iOS CoreMotion convention,
/// regardless of host platform.
///
/// Platform sensor callbacks are non-deterministic, so the service subscribes
/// to the raw streams at a fast rate, caches the latest reading from each, and
/// a periodic timer assembles one [SensorSample] per tick from those cached
/// values (last-value-hold). No interpolation: at 50 Hz the streams refresh
/// faster than the tick, so the held value is at most one stream period stale,
/// which is below the model's sensitivity.
class SensorService {
  /// Creates a service. [samplePeriod] is the resampler tick (default 50 Hz).
  SensorService({this.samplePeriod = const Duration(milliseconds: 20)});

  /// The fixed period between emitted samples. 20 ms ⇒ 50 Hz, matching the
  /// MotionSense recording rate the model was trained on.
  final Duration samplePeriod;

  final StreamController<SensorSample> _sampleController =
      StreamController<SensorSample>.broadcast();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<UserAccelerometerEvent>? _userAccelerationSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  Timer? _resampleTimer;

  AccelerometerEvent? _latestAccelerometer;
  UserAccelerometerEvent? _latestUserAcceleration;
  GyroscopeEvent? _latestGyroscope;

  /// Broadcast stream of resampled IMU samples in iOS convention.
  Stream<SensorSample> get samples => _sampleController.stream;

  /// Whether the resampler is currently running.
  bool get isRunning => _resampleTimer?.isActive ?? false;

  /// Subscribes to the underlying sensors and starts the resampler.
  ///
  /// Underlying streams are requested at [SensorInterval.gameInterval] (20 ms)
  /// so each holds a fresh value for every resampler tick.
  void start() {
    if (isRunning) return;
    const interval = SensorInterval.gameInterval;
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: interval,
    ).listen((event) => _latestAccelerometer = event);
    _userAccelerationSubscription = userAccelerometerEventStream(
      samplingPeriod: interval,
    ).listen((event) => _latestUserAcceleration = event);
    _gyroscopeSubscription = gyroscopeEventStream(
      samplingPeriod: interval,
    ).listen((event) => _latestGyroscope = event);
    _resampleTimer = Timer.periodic(samplePeriod, _onTick);
  }

  void _onTick(Timer _) {
    final accelerometer = _latestAccelerometer;
    final userAcceleration = _latestUserAcceleration;
    final gyroscope = _latestGyroscope;
    // Hold off until every stream has delivered at least one reading; emitting
    // partial samples would corrupt the derived gravity
    // (acceleration - userAcceleration).
    if (accelerometer == null ||
        userAcceleration == null ||
        gyroscope == null) {
      return;
    }
    _sampleController.add(
      SensorConversion.toIosConvention(
        timestamp: DateTime.now(),
        acceleration: (
          x: accelerometer.x,
          y: accelerometer.y,
          z: accelerometer.z,
        ),
        userAcceleration: (
          x: userAcceleration.x,
          y: userAcceleration.y,
          z: userAcceleration.z,
        ),
        rotationRate: (
          x: gyroscope.x,
          y: gyroscope.y,
          z: gyroscope.z,
        ),
      ),
    );
  }

  /// Stops the resampler and cancels all sensor subscriptions.
  Future<void> stop() async {
    _resampleTimer?.cancel();
    _resampleTimer = null;
    await _accelerometerSubscription?.cancel();
    await _userAccelerationSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _userAccelerationSubscription = null;
    _gyroscopeSubscription = null;
    _latestAccelerometer = null;
    _latestUserAcceleration = null;
    _latestGyroscope = null;
  }

  /// Releases the stream controller. The service cannot be reused afterwards.
  Future<void> dispose() async {
    await stop();
    await _sampleController.close();
  }
}
