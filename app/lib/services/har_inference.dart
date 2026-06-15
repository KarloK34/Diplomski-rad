import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/feature_window.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Loads `cnn_final.tflite` and runs HAR inference on normalized
/// [FeatureWindow]s, returning [ActivityPrediction]s.
///
/// Inference runs in a background isolate via [IsolateInterpreter] so the 50 Hz
/// sampler and UI thread are never blocked by an interpreter call. Numerical
/// agreement with the Python TFLite reference is validated on-device by
/// `integration_test/inference_parity_test.dart`.
class HarInference {
  HarInference._(this._interpreter, this._isolate, this.classLabels);

  static const String _modelAsset = 'assets/cnn_final.tflite';
  static const String _preprocAsset = 'assets/cnn_final.preproc.json';

  final Interpreter _interpreter;
  final IsolateInterpreter _isolate;

  /// Class labels in model output order, read from `cnn_final.preproc.json`.
  final List<String> classLabels;

  /// Loads the model and validates that its I/O contract matches the feature
  /// pipeline. Throws on any mismatch: a silently transposed tensor or a
  /// permuted channel order would degrade predictions without an obvious error.
  static Future<HarInference> load() async {
    final interpreter = await Interpreter.fromAsset(_modelAsset);

    final inputShape = interpreter.getInputTensor(0).shape;
    const expectedInput = [
      1,
      FeatureWindow.windowSize,
      FeatureWindow.channelCount,
    ];
    if (!_shapeEquals(inputShape, expectedInput)) {
      throw StateError(
        'TFLite input shape $inputShape != expected $expectedInput',
      );
    }

    // The preproc metadata is the contract the Dart pipeline was built
    // against; its channel order must match the constant the tensor is packed
    // in.
    final preproc =
        jsonDecode(await rootBundle.loadString(_preprocAsset))
            as Map<String, dynamic>;
    final channelOrder = (preproc['channel_order'] as List).cast<String>();
    if (!_listEquals(channelOrder, FeatureWindow.channelOrder)) {
      throw StateError(
        'preproc.json channel_order $channelOrder != '
        'FeatureWindow.channelOrder ${FeatureWindow.channelOrder}',
      );
    }

    final classLabels = (preproc['class_labels'] as List).cast<String>();
    final outputShape = interpreter.getOutputTensor(0).shape;
    if (!_shapeEquals(outputShape, [1, classLabels.length])) {
      throw StateError(
        'TFLite output shape $outputShape != '
        'expected [1, ${classLabels.length}]',
      );
    }

    final isolate = await IsolateInterpreter.create(
      address: interpreter.address,
    );
    return HarInference._(interpreter, isolate, classLabels);
  }

  /// Runs inference on one normalized window and returns the prediction with
  /// its measured latency.
  Future<ActivityPrediction> predict(FeatureWindow window) async {
    final input = [window.data]; // [1, 128, 8]
    // List<dynamic> outer wrapper: copyTo replaces output[0] with the decoded
    // float row, so a reified List<List<double>> would reject the assignment.
    final output = <dynamic>[List<double>.filled(classLabels.length, 0)];

    final stopwatch = Stopwatch()..start();
    await _isolate.run(input, output);
    stopwatch.stop();

    final probabilities = (output[0] as List)
        .map((v) => (v as num).toDouble())
        .toList();
    var argmax = 0;
    for (var i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > probabilities[argmax]) argmax = i;
    }

    return ActivityPrediction(
      label: classLabels[argmax],
      rawLabel: classLabels[argmax],
      probabilities: probabilities,
      timestamp: window.endTimestamp,
      inferenceLatencyMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Releases the isolate and the native interpreter.
  Future<void> close() async {
    await _isolate.close();
    _interpreter.close();
  }

  static bool _shapeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
