import 'package:equatable/equatable.dart';

/// A single normalized feature window ready for model inference.
///
/// [data] is a 128×8 row-major tensor: 128 time steps, each an 8-channel
/// vector in the order declared by [FeatureWindow.channelOrder]. Values are
/// per-window instance Z-score normalized (see `feature_pipeline.dart`).
class FeatureWindow extends Equatable {
  /// Creates a window. [data] must be 128 rows of 8 channels.
  const FeatureWindow({
    required this.data,
    required this.endTimestamp,
    required this.endSampleIndex,
  });

  /// Output channel order. Must match `cnn_final.preproc.json.channel_order`
  /// byte-for-byte — the TFLite input is order-sensitive and silently
  /// degenerates if the channels are permuted.
  static const List<String> channelOrder = [
    'acc_mag',
    'gyro_mag',
    'a_v',
    'a_h',
    'jerk_v',
    'a_f_mag',
    'a_s_mag',
    'gyro_v',
  ];

  /// Number of time steps per window (2.56 s @ 50 Hz).
  static const int windowSize = 128;

  /// Number of channels per time step.
  static const int channelCount = 8;

  /// Normalized window, shape [windowSize][channelCount].
  final List<List<double>> data;

  /// Wall-clock time of the last sample in the window.
  final DateTime endTimestamp;

  /// Index of the last sample (in the session sample stream) in this window.
  final int endSampleIndex;

  @override
  List<Object?> get props => [data, endTimestamp, endSampleIndex];
}
