import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/feature_window.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/services/feature_pipeline.dart';

/// Behavioural tests for the causal live path. These do NOT check numerical
/// parity (that is the offline path, `feature_pipeline_test.dart`); they verify
/// the streaming extractor's window cadence and that it produces finite,
/// well-shaped, normalized output.
void main() {
  SensorSample syntheticSample(int t) {
    // A plausible walking-like signal: ~1 g gravity on z, small oscillating
    // user acceleration and rotation. Gravity is non-zero so g_hat is defined.
    final angle = 2 * pi * t / 25; // ~2 Hz step cadence at 50 Hz
    return SensorSample(
      timestamp: DateTime.fromMillisecondsSinceEpoch(t * 20),
      gravityX: 0.05 * sin(angle),
      gravityY: 0.1,
      gravityZ: -0.99,
      userAccelerationX: 0.3 * sin(angle),
      userAccelerationY: 0.2 * cos(angle),
      userAccelerationZ: 0.4 * sin(angle),
      rotationRateX: 0.5 * cos(angle),
      rotationRateY: 0.1 * sin(angle),
      rotationRateZ: 0.2 * cos(angle),
    );
  }

  test('emits a window at sample 128 and every 64 samples thereafter', () {
    final extractor = StreamingFeatureExtractor();
    final emittedAt = <int>[];
    for (var t = 0; t < 256; t++) {
      final window = extractor.add(syntheticSample(t));
      if (window != null) emittedAt.add(t + 1); // 1-based sample count
    }
    expect(emittedAt, [128, 192, 256]);
  });

  test('emitted windows are 128×8, finite, and per-window normalized', () {
    final extractor = StreamingFeatureExtractor();
    FeatureWindow? last;
    for (var t = 0; t < 256; t++) {
      final window = extractor.add(syntheticSample(t));
      if (window != null) last = window;
    }
    expect(last, isNotNull);
    final data = last!.data;
    expect(data.length, FeatureWindow.windowSize);
    expect(data.first.length, FeatureWindow.channelCount);

    for (var c = 0; c < FeatureWindow.channelCount; c++) {
      var sum = 0.0;
      for (var t = 0; t < FeatureWindow.windowSize; t++) {
        expect(data[t][c].isFinite, isTrue);
        sum += data[t][c];
      }
      // Per-window Z-score ⇒ each channel mean ≈ 0.
      expect((sum / FeatureWindow.windowSize).abs(), lessThan(1e-6));
    }
  });

  test('reset clears buffered state so cadence restarts', () {
    final extractor = StreamingFeatureExtractor();
    for (var t = 0; t < 200; t++) {
      extractor.add(syntheticSample(t));
    }
    extractor.reset();
    final emittedAt = <int>[];
    for (var t = 0; t < 128; t++) {
      final window = extractor.add(syntheticSample(t));
      if (window != null) emittedAt.add(t + 1);
    }
    expect(emittedAt, [128]);
  });
}
