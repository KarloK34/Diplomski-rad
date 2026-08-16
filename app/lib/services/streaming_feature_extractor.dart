import 'package:gait_sense/models/feature_window.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/services/feature_pipeline.dart';

/// Stateful, causal feature extractor for the live sensor stream.
///
/// Maintains a trailing context buffer (default 250 +
/// [FeatureWindow.windowSize] samples, i.e. 7.56 s) for the walking-direction
/// smoothing and emits a normalized [FeatureWindow] every [step] samples once
/// at least [FeatureWindow.windowSize] samples are available. Unlike the
/// parity-validated offline path, the smoothing here uses only past samples
/// — a deliberate causal approximation, since live inference cannot see
/// future samples.
///
/// `contextSamples` must exceed the smoothing kernel length
/// (`round(smoothSeconds * fsHz)`, 250 samples by default) or
/// `_movingAverageSame` degenerates to a no-op (it returns the input
/// unchanged whenever the buffer is not longer than the kernel), silently
/// disabling the smoothing and collapsing `a_f_mag`/`a_s_mag` into a
/// duplicate of `a_h` and a constant zero. The default below keeps the full
/// 250-sample kernel and adds one window of headroom past it.
class StreamingFeatureExtractor {
  /// Creates an extractor. `contextSamples` must be at least one full window
  /// ([FeatureWindow.windowSize]) *and* strictly greater than the smoothing
  /// kernel length, or the walking-direction moving average never fires.
  StreamingFeatureExtractor({
    this.contextSamples = 250 + FeatureWindow.windowSize,
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
