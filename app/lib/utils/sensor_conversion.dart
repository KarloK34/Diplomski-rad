import 'dart:math';

import 'package:gait_sense/models/sensor_sample.dart';

/// Standard gravity (m/s²). sensors_plus reports acceleration in m/s² on both
/// platforms, while the model was trained on MotionSense data in units of g.
/// Dividing by this constant recovers g.
///
/// Source: cnn_final.preproc.json ->
/// android_to_ios_conversion.gravity_g_constant.
const double kStandardGravity = 9.80665;

/// Converts raw sensors_plus readings into the iOS CoreMotion convention the
/// model expects.
///
/// sensors_plus does not expose a gravity stream, so gravity is derived as
/// `accelerometer - userAccelerometer`: on Android TYPE_ACCELEROMETER already
/// equals gravity + linear acceleration and TYPE_LINEAR_ACCELERATION is the
/// linear part, so their difference is the sensor-fused gravity. This is more
/// faithful than an exponential-moving-average low-pass and needs no warm-up.
///
/// Sign and unit rules follow cnn_final.preproc.json:
///  - Android: negate each acceleration axis and divide by g; rotation rate is
///    left untouched (gyroscope convention matches iOS).
///  - iOS: sensors_plus already reports in the iOS sign convention, so only the
///    unit rescale (÷ g) is applied.
///
/// References:
///  - Sensor Logger CROSSPLATFORM.md / COORDINATES.md (sign conventions)
///  - Apple CMDeviceMotion docs (iOS native frame)
class SensorConversion {
  const SensorConversion._();

  /// Builds a [SensorSample] in iOS convention from raw m/s² / rad/s readings.
  ///
  /// [acceleration] is the total accelerometer reading (gravity + linear) in
  /// m/s², [userAcceleration] the linear acceleration (gravity removed) in
  /// m/s², and [rotationRate] the angular velocity in rad/s — all in the host
  /// platform's native frame. [isAndroid] selects the platform-specific sign
  /// handling.
  static SensorSample toIosConvention({
    required DateTime timestamp,
    required ({double x, double y, double z}) acceleration,
    required ({double x, double y, double z}) userAcceleration,
    required ({double x, double y, double z}) rotationRate,
    required bool isAndroid,
  }) {
    // Derived gravity in the native frame (m/s²).
    final gravityNativeX = acceleration.x - userAcceleration.x;
    final gravityNativeY = acceleration.y - userAcceleration.y;
    final gravityNativeZ = acceleration.z - userAcceleration.z;

    // Single factor combining the sign flip (Android only) and the m/s² → g
    // rescale. Gravity and user acceleration share the accelerometer frame so
    // they use the same factor.
    final accelerationScale = (isAndroid ? -1.0 : 1.0) / kStandardGravity;

    return SensorSample(
      timestamp: timestamp,
      gravityX: gravityNativeX * accelerationScale,
      gravityY: gravityNativeY * accelerationScale,
      gravityZ: gravityNativeZ * accelerationScale,
      userAccelerationX: userAcceleration.x * accelerationScale,
      userAccelerationY: userAcceleration.y * accelerationScale,
      userAccelerationZ: userAcceleration.z * accelerationScale,
      // Rotation rate: identical convention across platforms, no change.
      rotationRateX: rotationRate.x,
      rotationRateY: rotationRate.y,
      rotationRateZ: rotationRate.z,
    );
  }
}

/// Projects the user acceleration of [sample] onto the gravity direction,
/// returning the signed vertical component in the same units as
/// [SensorSample.userAccelerationX] (standard gravity, g).
///
/// The projection `aV = u_a · g_hat` isolates the component of movement
/// aligned with gravity regardless of how the phone is oriented in the pocket.
/// It is used by both the feature pipeline (as the `a_v` channel) and the
/// walking-speed estimator (as the vertical displacement signal). Centralising
/// the computation here ensures both callers use the identical formula.
///
/// Returns 0 when the gravity vector is near-zero (sensor failure or free
/// fall), matching the `eps` guard in the feature pipeline.
double verticalAcceleration(SensorSample sample) {
  final gNorm = sqrt(
    sample.gravityX * sample.gravityX +
        sample.gravityY * sample.gravityY +
        sample.gravityZ * sample.gravityZ,
  );
  if (gNorm < 1e-9) return 0;
  return (sample.userAccelerationX * sample.gravityX +
          sample.userAccelerationY * sample.gravityY +
          sample.userAccelerationZ * sample.gravityZ) /
      gNorm;
}
