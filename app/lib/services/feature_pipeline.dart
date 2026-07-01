import 'dart:math';

import 'package:gait_sense/models/feature_window.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/utils/sensor_conversion.dart';

/// Walking-frame v2 feature extraction, ported one-to-one from the canonical
/// Python implementation `compute_walking_frame_features_v2`
/// (`ml/utils/orientation_invariant_features.py`).
///
/// The 8 output channels are invariant to rotation of the phone about the
/// gravity axis (yaw), the dominant nuisance in pocket placement
/// (Mizell, 2003, https://doi.org/10.1109/ISWC.2003.1241424; Henpraserttae
/// et al., 2011, https://doi.org/10.1109/BSN.2011.8). `computeBlockFeatures` is
/// validated against the Python reference to < 1e-4 in `test/feature_pipeline_test.dart`.
///
/// Two consumers share the same math:
///  - the parity test feeds a *whole session* as one block (matching the
///    non-causal, whole-session smoothing the model was trained on);
///  - [StreamingFeatureExtractor] feeds a trailing context buffer, which is a
///    deliberate causal approximation (future samples are unavailable live).
class FeaturePipeline {
  const FeaturePipeline._();

  /// Default sampling rate the model was trained on.
  static const double fsHz = 50;

  /// Walking-direction smoothing horizon.
  static const double smoothSeconds = 5;

  /// Near-zero threshold for direction vectors (Python `eps = 1e-3`, ~1 mg).
  static const double _eps = 1e-3;

  /// Computes the 8 walking-frame v2 channels for a contiguous block of
  /// samples (already in iOS convention). Returns a `block.length` × 8 matrix
  /// in [FeatureWindow.channelOrder] order.
  ///
  /// Time derivatives (`jerk_v`) and the walking-direction smoothing must not
  /// bridge unrelated recordings, so callers pass one contiguous block.
  static List<List<double>> computeBlockFeatures(
    List<SensorSample> block, {
    double fsHz = fsHz,
    double smoothSeconds = smoothSeconds,
  }) {
    final n = block.length;
    if (n == 0) return const [];

    // Per-sample magnitudes, gravity unit vector, vertical/horizontal split.
    final accMag = List<double>.filled(n, 0);
    final gyroMag = List<double>.filled(n, 0);
    final gHat = List<List<double>>.generate(
      n,
      (_) => List<double>.filled(3, 0),
    );
    final aV = List<double>.filled(n, 0);
    final aH = List<double>.filled(n, 0);
    // Horizontal residual of user acceleration, reused for the smoothing step.
    final uaHorizontal = List<List<double>>.generate(
      n,
      (_) => List<double>.filled(3, 0),
    );
    // Cache user acceleration / rotation as arrays for the projection steps.
    final ua = List<List<double>>.generate(n, (_) => List<double>.filled(3, 0));
    final omega = List<List<double>>.generate(
      n,
      (_) => List<double>.filled(3, 0),
    );

    for (var t = 0; t < n; t++) {
      final s = block[t];
      ua[t][0] = s.userAccelerationX;
      ua[t][1] = s.userAccelerationY;
      ua[t][2] = s.userAccelerationZ;
      omega[t][0] = s.rotationRateX;
      omega[t][1] = s.rotationRateY;
      omega[t][2] = s.rotationRateZ;

      accMag[t] = _norm3(ua[t][0], ua[t][1], ua[t][2]);
      gyroMag[t] = _norm3(omega[t][0], omega[t][1], omega[t][2]);

      final gNorm = _norm3(s.gravityX, s.gravityY, s.gravityZ);
      gHat[t][0] = s.gravityX / gNorm;
      gHat[t][1] = s.gravityY / gNorm;
      gHat[t][2] = s.gravityZ / gNorm;

      // Vertical projection a_v = u_a · g_hat (signed).
      aV[t] = verticalAcceleration(s);

      // Horizontal residual and its magnitude (Mizell, 2003).
      uaHorizontal[t][0] = ua[t][0] - aV[t] * gHat[t][0];
      uaHorizontal[t][1] = ua[t][1] - aV[t] * gHat[t][1];
      uaHorizontal[t][2] = ua[t][2] - aV[t] * gHat[t][2];
      aH[t] = _norm3(
        uaHorizontal[t][0],
        uaHorizontal[t][1],
        uaHorizontal[t][2],
      );
    }

    // Vertical jerk: discrete derivative of a_v, first sample replicated from
    // the second so the output length is preserved.
    final jerkV = List<double>.filled(n, 0);
    if (n >= 2) {
      final dt = 1.0 / fsHz;
      for (var t = 1; t < n; t++) {
        jerkV[t] = (aV[t] - aV[t - 1]) / dt;
      }
      jerkV[0] = jerkV[1];
    }

    // Walking-direction body frame.
    final smoothSamples = max(1, (smoothSeconds * fsHz).round());
    final uaHorizontalSmooth = _movingAverageSame(uaHorizontal, smoothSamples);

    final smoothNorm = List<double>.filled(n, 0);
    for (var t = 0; t < n; t++) {
      smoothNorm[t] = _norm3(
        uaHorizontalSmooth[t][0],
        uaHorizontalSmooth[t][1],
        uaHorizontalSmooth[t][2],
      );
    }

    // Block-mean smoothed horizontal direction.
    var meanDirX = 0.0;
    var meanDirY = 0.0;
    var meanDirZ = 0.0;
    for (var t = 0; t < n; t++) {
      meanDirX += uaHorizontalSmooth[t][0];
      meanDirY += uaHorizontalSmooth[t][1];
      meanDirZ += uaHorizontalSmooth[t][2];
    }
    meanDirX /= n;
    meanDirY /= n;
    meanDirZ /= n;
    final meanDirNorm = _norm3(meanDirX, meanDirY, meanDirZ);

    final fHat = List<List<double>>.generate(
      n,
      (_) => List<double>.filled(3, 0),
    );
    if (meanDirNorm < _eps) {
      // No coherent direction in the block (sit/std): build a deterministic
      // horizontal axis by projecting world-X onto the plane orthogonal to the
      // block-mean gravity.
      var meanGX = 0.0;
      var meanGY = 0.0;
      var meanGZ = 0.0;
      for (var t = 0; t < n; t++) {
        meanGX += gHat[t][0];
        meanGY += gHat[t][1];
        meanGZ += gHat[t][2];
      }
      meanGX /= n;
      meanGY /= n;
      meanGZ /= n;
      final meanGNorm = _norm3(meanGX, meanGY, meanGZ);
      meanGX /= meanGNorm;
      meanGY /= meanGNorm;
      meanGZ /= meanGNorm;

      var fDefault = _projectOntoPlane([1, 0, 0], [meanGX, meanGY, meanGZ]);
      if (_norm3(fDefault[0], fDefault[1], fDefault[2]) < _eps) {
        fDefault = _projectOntoPlane([0, 1, 0], [meanGX, meanGY, meanGZ]);
      }
      final projNorm = _norm3(fDefault[0], fDefault[1], fDefault[2]);
      final denom = max(projNorm, _eps);
      fDefault = [
        fDefault[0] / denom,
        fDefault[1] / denom,
        fDefault[2] / denom,
      ];
      for (var t = 0; t < n; t++) {
        fHat[t][0] = fDefault[0];
        fHat[t][1] = fDefault[1];
        fHat[t][2] = fDefault[2];
      }
    } else {
      final fDefault = [
        meanDirX / meanDirNorm,
        meanDirY / meanDirNorm,
        meanDirZ / meanDirNorm,
      ];
      for (var t = 0; t < n; t++) {
        if (smoothNorm[t] < _eps) {
          fHat[t][0] = fDefault[0];
          fHat[t][1] = fDefault[1];
          fHat[t][2] = fDefault[2];
        } else {
          fHat[t][0] = uaHorizontalSmooth[t][0] / smoothNorm[t];
          fHat[t][1] = uaHorizontalSmooth[t][1] / smoothNorm[t];
          fHat[t][2] = uaHorizontalSmooth[t][2] / smoothNorm[t];
        }
      }
    }

    final features = List<List<double>>.generate(
      n,
      (_) => List<double>.filled(FeatureWindow.channelCount, 0),
    );
    for (var t = 0; t < n; t++) {
      // Re-orthogonalise f_hat against g_hat so it lies in the
      // horizontal plane, then build the right-handed body frame.
      final dot =
          fHat[t][0] * gHat[t][0] +
          fHat[t][1] * gHat[t][1] +
          fHat[t][2] * gHat[t][2];
      var fx = fHat[t][0] - dot * gHat[t][0];
      var fy = fHat[t][1] - dot * gHat[t][1];
      var fz = fHat[t][2] - dot * gHat[t][2];
      final fNorm = max(_norm3(fx, fy, fz), _eps);
      fx /= fNorm;
      fy /= fNorm;
      fz /= fNorm;

      // s_hat = f_hat × g_hat.
      final sx = fy * gHat[t][2] - fz * gHat[t][1];
      final sy = fz * gHat[t][0] - fx * gHat[t][2];
      final sz = fx * gHat[t][1] - fy * gHat[t][0];

      final aF = ua[t][0] * fx + ua[t][1] * fy + ua[t][2] * fz;
      final aS = ua[t][0] * sx + ua[t][1] * sy + ua[t][2] * sz;
      final gyroV =
          omega[t][0] * gHat[t][0] +
          omega[t][1] * gHat[t][1] +
          omega[t][2] * gHat[t][2];

      features[t][0] = accMag[t];
      features[t][1] = gyroMag[t];
      features[t][2] = aV[t];
      features[t][3] = aH[t];
      features[t][4] = jerkV[t];
      // v2 sign-invariant magnitudes for the forward/lateral axes; gyro_v stays
      // signed.
      features[t][5] = aF.abs();
      features[t][6] = aS.abs();
      features[t][7] = gyroV;
    }
    return features;
  }

  /// Per-window instance Z-score over time, per channel: denominator N
  /// (population std) with a `+1e-8` floor, matching `normalize_dyn` in the
  /// training notebooks. `window` is a `w` × channel matrix.
  static List<List<double>> normalizeWindow(List<List<double>> window) {
    final w = window.length;
    final c = window.isEmpty ? 0 : window.first.length;
    final out = List<List<double>>.generate(
      w,
      (_) => List<double>.filled(c, 0),
    );
    for (var ch = 0; ch < c; ch++) {
      var sum = 0.0;
      for (var t = 0; t < w; t++) {
        sum += window[t][ch];
      }
      final mean = sum / w;
      var sqSum = 0.0;
      for (var t = 0; t < w; t++) {
        final d = window[t][ch] - mean;
        sqSum += d * d;
      }
      final std = sqrt(sqSum / w) + 1e-8;
      for (var t = 0; t < w; t++) {
        out[t][ch] = (window[t][ch] - mean) / std;
      }
    }
    return out;
  }

  /// Slices a feature matrix into normalized windows of length [windowSize]
  /// with step [step], matching `sliding_windows` (st in 0..N-w step s).
  /// Convenience for offline use (parity test); the live path uses
  /// [StreamingFeatureExtractor].
  static List<List<List<double>>> windows(
    List<List<double>> features, {
    int windowSize = FeatureWindow.windowSize,
    int step = FeatureWindow.windowSize ~/ 2,
  }) {
    final result = <List<List<double>>>[];
    for (var st = 0; st + windowSize <= features.length; st += step) {
      result.add(normalizeWindow(features.sublist(st, st + windowSize)));
    }
    return result;
  }

  /// Centred boxcar moving average replicating numpy's
  /// `convolve(.., mode='same')` with implicit zero-padding: boundary outputs
  /// sum fewer real samples but still divide by `windowSamples`, so edges are
  /// attenuated exactly as in the Python reference. Falls back to a copy when
  /// the block is not longer than the kernel (matches `_moving_average`).
  static List<List<double>> _movingAverageSame(
    List<List<double>> arr,
    int windowSamples,
  ) {
    final n = arr.length;
    final dim = n == 0 ? 0 : arr.first.length;
    if (windowSamples <= 1 || n <= windowSamples) {
      return [for (final row in arr) List<double>.of(row)];
    }
    // np.convolve 'same' picks full[i + (K-1)//2]; the contributing source
    // indices span [i - K//2 .. i + (K-1)//2].
    final halfRight = (windowSamples - 1) ~/ 2;
    final halfLeft = windowSamples - 1 - halfRight;
    final out = List<List<double>>.generate(
      n,
      (_) => List<double>.filled(dim, 0),
    );
    for (var d = 0; d < dim; d++) {
      // Prefix sums for O(N) windowed sums; missing (padded) entries are zero.
      final prefix = List<double>.filled(n + 1, 0);
      for (var i = 0; i < n; i++) {
        prefix[i + 1] = prefix[i] + arr[i][d];
      }
      for (var i = 0; i < n; i++) {
        final lo = max(0, i - halfLeft);
        final hi = min(n - 1, i + halfRight);
        out[i][d] = (prefix[hi + 1] - prefix[lo]) / windowSamples;
      }
    }
    return out;
  }

  static List<double> _projectOntoPlane(
    List<double> v,
    List<double> unitNormal,
  ) {
    final dot =
        v[0] * unitNormal[0] + v[1] * unitNormal[1] + v[2] * unitNormal[2];
    return [
      v[0] - dot * unitNormal[0],
      v[1] - dot * unitNormal[1],
      v[2] - dot * unitNormal[2],
    ];
  }

  static double _norm3(double x, double y, double z) =>
      sqrt(x * x + y * y + z * z);
}

/// Stateful, causal feature extractor for the live sensor stream.
///
/// Maintains a trailing context buffer (default 250 samples / 5 s) for the
/// walking-direction smoothing and emits a normalized [FeatureWindow] every
/// [step] samples once at least [FeatureWindow.windowSize] samples are
/// available. Unlike the parity-validated offline path, the smoothing here uses
/// only past samples — a deliberate causal approximation, since live inference
/// cannot see future samples.
class StreamingFeatureExtractor {
  /// Creates an extractor. `contextSamples` must be at least one full window
  /// ([FeatureWindow.windowSize]).
  StreamingFeatureExtractor({
    this.contextSamples = 250,
    this.step = FeatureWindow.windowSize ~/ 2,
  }) : assert(
         contextSamples >= FeatureWindow.windowSize,
         'context must hold at least one full window',
       );

  /// Trailing buffer length used for walking-direction smoothing.
  final int contextSamples;

  /// Samples between emitted windows (64 ⇒ a new window every 1.28 s).
  final int step;

  final List<SensorSample> _buffer = [];
  int _totalSamples = 0;
  int _samplesSinceLastWindow = 0;

  /// Feeds one sample. Returns a normalized [FeatureWindow] when a new window
  /// boundary is reached, otherwise null.
  FeatureWindow? add(SensorSample sample) {
    _buffer.add(sample);
    _totalSamples++;
    if (_buffer.length > contextSamples) {
      _buffer.removeAt(0);
    }
    _samplesSinceLastWindow++;

    if (_buffer.length < FeatureWindow.windowSize) return null;
    if (_samplesSinceLastWindow < step) return null;
    _samplesSinceLastWindow = 0;

    // Compute features over the whole trailing context, then keep the most
    // recent full window for the per-window normalization.
    final features = FeaturePipeline.computeBlockFeatures(_buffer);
    final window = features.sublist(features.length - FeatureWindow.windowSize);
    return FeatureWindow(
      data: FeaturePipeline.normalizeWindow(window),
      endTimestamp: sample.timestamp,
      endSampleIndex: _totalSamples - 1,
    );
  }

  /// Clears all buffered state for a fresh session.
  void reset() {
    _buffer.clear();
    _totalSamples = 0;
    _samplesSinceLastWindow = 0;
  }
}
