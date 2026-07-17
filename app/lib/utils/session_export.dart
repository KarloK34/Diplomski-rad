import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [session] as pretty-printed JSON to a temp file and hands it to
/// the OS share sheet, anchored below [context]'s render box on iPad/iOS.
Future<void> shareSessionLog(BuildContext context, SessionLog session) async {
  final renderBox = context.findRenderObject() as RenderBox?;
  final origin = renderBox != null && renderBox.hasSize
      ? renderBox.localToGlobal(Offset.zero) & renderBox.size
      : null;

  final directory = await getTemporaryDirectory();
  final stamp = session.startedAt.toIso8601String().replaceAll(':', '-');
  final file = File('${directory.path}/session_$stamp.json');
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(session.toJson()),
  );
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      subject: 'Gait Sense — sesija',
      text: 'Zapis HAR sesije (${session.predictions.length} predikcija).',
      sharePositionOrigin: origin,
    ),
  );
}
