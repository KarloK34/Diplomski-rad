import 'package:equatable/equatable.dart';

/// A single IMU sample expressed in the iOS CoreMotion convention the model
/// was trained on (MotionSense): gravity and user acceleration in units of
/// standard gravity (g), rotation rate in rad/s.
class SensorSample extends Equatable {
  /// Creates a sample. All acceleration fields are in g; rotation in rad/s.
  const SensorSample({
    required this.timestamp,
    required this.gravityX,
    required this.gravityY,
    required this.gravityZ,
    required this.userAccelerationX,
    required this.userAccelerationY,
    required this.userAccelerationZ,
    required this.rotationRateX,
    required this.rotationRateY,
    required this.rotationRateZ,
  });

  /// Wall-clock time the sample was emitted by the resampler.
  final DateTime timestamp;

  /// Gravity vector x-component (g).
  final double gravityX;

  /// Gravity vector y-component (g).
  final double gravityY;

  /// Gravity vector z-component (g).
  final double gravityZ;

  /// User (linear) acceleration x-component, gravity removed (g).
  final double userAccelerationX;

  /// User (linear) acceleration y-component, gravity removed (g).
  final double userAccelerationY;

  /// User (linear) acceleration z-component, gravity removed (g).
  final double userAccelerationZ;

  /// Angular velocity x-component (rad/s).
  final double rotationRateX;

  /// Angular velocity y-component (rad/s).
  final double rotationRateY;

  /// Angular velocity z-component (rad/s).
  final double rotationRateZ;

  @override
  List<Object?> get props => [
    timestamp,
    gravityX,
    gravityY,
    gravityZ,
    userAccelerationX,
    userAccelerationY,
    userAccelerationZ,
    rotationRateX,
    rotationRateY,
    rotationRateZ,
  ];
}
