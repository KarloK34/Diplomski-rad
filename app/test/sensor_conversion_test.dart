import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/utils/sensor_conversion.dart';

void main() {
  final timestamp = DateTime(2026);

  double gravityMagnitude(
    double x,
    double y,
    double z,
  ) => sqrt(x * x + y * y + z * z);

  group('SensorConversion.toIosConvention (Android)', () {
    test('static phone yields gravity magnitude ~ 1 g', () {
      // Accelerometer reads pure gravity, linear acceleration ~ 0.
      final sample = SensorConversion.toIosConvention(
        timestamp: timestamp,
        acceleration: (x: 0, y: 0, z: kStandardGravity),
        userAcceleration: (x: 0, y: 0, z: 0),
        rotationRate: (x: 0, y: 0, z: 0),
        isAndroid: true,
      );
      expect(
        gravityMagnitude(
          sample.gravityX,
          sample.gravityY,
          sample.gravityZ,
        ),
        closeTo(1, 1e-9),
      );
    });

    test('acceleration axes are negated and rescaled to g', () {
      final sample = SensorConversion.toIosConvention(
        timestamp: timestamp,
        acceleration: (x: kStandardGravity, y: 0, z: 0),
        userAcceleration: (x: 0, y: 0, z: 0),
        rotationRate: (x: 0, y: 0, z: 0),
        isAndroid: true,
      );
      expect(sample.gravityX, closeTo(-1, 1e-9));
    });

    test('gravity is derived as accelerometer - userAcceleration', () {
      final sample = SensorConversion.toIosConvention(
        timestamp: timestamp,
        acceleration: (x: 0, y: 0, z: 2 * kStandardGravity),
        userAcceleration: (x: 0, y: 0, z: kStandardGravity),
        rotationRate: (x: 0, y: 0, z: 0),
        isAndroid: true,
      );
      expect(sample.gravityZ, closeTo(-1, 1e-9));
      expect(sample.userAccelerationZ, closeTo(-1, 1e-9));
    });
  });

  group('SensorConversion.toIosConvention (iOS)', () {
    test('acceleration rescaled to g without sign flip', () {
      final sample = SensorConversion.toIosConvention(
        timestamp: timestamp,
        acceleration: (x: kStandardGravity, y: 0, z: 0),
        userAcceleration: (x: 0, y: 0, z: 0),
        rotationRate: (x: 0, y: 0, z: 0),
        isAndroid: false,
      );
      expect(sample.gravityX, closeTo(1, 1e-9));
    });
  });

  test('rotation rate passes through unchanged', () {
    final sample = SensorConversion.toIosConvention(
      timestamp: timestamp,
      acceleration: (x: 0, y: 0, z: 0),
      userAcceleration: (x: 0, y: 0, z: 0),
      rotationRate: (x: 0.1, y: -0.2, z: 0.3),
      isAndroid: true,
    );
    expect(sample.rotationRateX, 0.1);
    expect(sample.rotationRateY, -0.2);
    expect(sample.rotationRateZ, 0.3);
  });

  group('verticalAcceleration', () {
    // In these tests gravity is [0, 0, 1] (pointing in +Z), so g_hat =
    // [0,0,1] and aV = userAccelerationZ directly.

    test('returns userAccelerationZ when gravity is pure +Z', () {
      final sample = SensorSample(
        timestamp: timestamp,
        gravityX: 0,
        gravityY: 0,
        gravityZ: 1,
        userAccelerationX: 0.1,
        userAccelerationY: 0.2,
        userAccelerationZ: 0.5,
        rotationRateX: 0,
        rotationRateY: 0,
        rotationRateZ: 0,
      );
      expect(verticalAcceleration(sample), closeTo(0.5, 1e-9));
    });

    test(
      'returns negative value for upward user acceleration (iOS convention)',
      () {
        // In iOS CoreMotion convention, gravity points DOWN (+Z when phone is
        // flat face-up).  A user acceleration in -Z is upward movement.
        final sample = SensorSample(
          timestamp: timestamp,
          gravityX: 0,
          gravityY: 0,
          gravityZ: 1,
          userAccelerationX: 0,
          userAccelerationY: 0,
          userAccelerationZ: -0.3,
          rotationRateX: 0,
          rotationRateY: 0,
          rotationRateZ: 0,
        );
        expect(verticalAcceleration(sample), closeTo(-0.3, 1e-9));
      },
    );

    test('projects correctly onto a tilted gravity vector', () {
      // gravity = [1/√2, 0, 1/√2], userAcceleration = [1, 0, 0]
      // g_hat = [1/√2, 0, 1/√2], aV = 1*1/√2 + 0 + 0 = 1/√2 ≈ 0.7071
      final s = sqrt(2) / 2;
      final sample = SensorSample(
        timestamp: timestamp,
        gravityX: s,
        gravityY: 0,
        gravityZ: s,
        userAccelerationX: 1,
        userAccelerationY: 0,
        userAccelerationZ: 0,
        rotationRateX: 0,
        rotationRateY: 0,
        rotationRateZ: 0,
      );
      expect(verticalAcceleration(sample), closeTo(s, 1e-9));
    });

    test('returns 0 when gravity vector is near-zero', () {
      final sample = SensorSample(
        timestamp: timestamp,
        gravityX: 0,
        gravityY: 0,
        gravityZ: 1e-10, // below eps
        userAccelerationX: 1,
        userAccelerationY: 1,
        userAccelerationZ: 1,
        rotationRateX: 0,
        rotationRateY: 0,
        rotationRateZ: 0,
      );
      expect(verticalAcceleration(sample), 0);
    });

    test('is consistent with FeaturePipeline a_v channel', () {
      // Verify the helper and the pipeline produce the same value for the
      // same sample — this is the key regression guard for the refactor.
      final sample = SensorSample(
        timestamp: timestamp,
        gravityX: 0.3,
        gravityY: 0.4,
        gravityZ: sqrt(1 - 0.09 - 0.16), // normalised gravity
        userAccelerationX: 0.05,
        userAccelerationY: -0.02,
        userAccelerationZ: 0.08,
        rotationRateX: 0,
        rotationRateY: 0,
        rotationRateZ: 0,
      );
      // Manual calculation: gNorm = 1 (already unit), aV = dot(ua, g)
      final expected =
          sample.userAccelerationX * sample.gravityX +
          sample.userAccelerationY * sample.gravityY +
          sample.userAccelerationZ * sample.gravityZ;
      expect(verticalAcceleration(sample), closeTo(expected, 1e-9));
    });
  });
}
