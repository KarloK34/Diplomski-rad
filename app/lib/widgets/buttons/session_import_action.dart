import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/extensions/snackbar_context.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/repositories/session_log_repository.dart';
import 'package:go_router/go_router.dart';

/// Debug action that loads a session JSON file from disk — e.g. one
/// exported earlier via the summary screen's "Izvezi sesiju" action — and
/// opens it on the summary screen as if it had just finished recording.
///
/// Lets a session captured once be replayed for development and testing
/// without repeating the physical walk each time.
class SessionImportAction extends StatelessWidget {
  /// Creates the import action icon button.
  const SessionImportAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.file_open_outlined),
      tooltip: 'Uvezi sesiju (debug)',
      onPressed: () => unawaited(_import(context)),
    );
  }

  Future<void> _import(BuildContext context) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Session JSON', extensions: ['json']),
      ],
    );
    if (file == null || !context.mounted) return;

    final repository = context.read<SessionLogRepository>();
    final SessionLog session;
    try {
      session = repository.importFromJson(await file.readAsString());
    } on Object catch (error) {
      if (!context.mounted) return;
      context.showSnackBar('Neuspješan uvoz sesije: $error');
      return;
    }

    if (!context.mounted) return;
    unawaited(context.push(AppRoutes.recordRecoveredSummary, extra: session));
  }
}
