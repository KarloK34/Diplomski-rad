import 'package:gait_sense/models/feature_window.dart';

/// Model I/O contract recorded into every session log so an exported file is
/// self-describing without the app bundle.
///
/// `class_labels` are in model output order. The authoritative copy lives in
/// `assets/cnn_final.preproc.json`; `HarInference.load` validates the live
/// channel order against [FeatureWindow.channelOrder] at startup. If the model
/// is ever retrained with relabeled classes, this constant must be updated to
/// match — nothing validates the UI-isolate copy against the asset, because the
/// asset is only loaded in the service isolate.
const Map<String, dynamic> harModelInfo = <String, dynamic>{
  'channel_order': FeatureWindow.channelOrder,
  'class_labels': <String>['dws', 'ups', 'wlk', 'jog', 'std', 'sit'],
};
