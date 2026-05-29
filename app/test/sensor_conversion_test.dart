import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
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
}
