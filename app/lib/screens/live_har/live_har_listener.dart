import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/ui/ui_bloc.dart';
import 'package:gait_sense/blocs/ui/ui_event.dart';
import 'package:gait_sense/blocs/ui/ui_state.dart';
import 'package:gait_sense/extensions/snackbar_context.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/screens/session_summary/session_summary_screen.dart';
import 'package:go_router/go_router.dart';

/// Handles the one-shot side effect of a finished recording: pushes
/// [SessionSummaryScreen] and resets [UiBloc] back to idle on return.
class LiveHarListener extends StatelessWidget {
  /// Wraps [child] with the save-and-navigate side effect.
  const LiveHarListener({required this.child, super.key});

  /// The subtree rendering the current state.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<UiBloc, UiState>(
      // Fire once on the transition into the saved state, not on every
      // rebuild while it stays saved.
      listenWhen: (previous, current) =>
          previous.status != RecordingStatus.saved &&
          current.status == RecordingStatus.saved,
      listener: (context, state) {
        final session = state.finishedSession;
        if (session == null) return;

        if (state.stoppedByLimit) {
          context.showSnackBar(
            'Sesija je automatski zaustavljena — dostignut je limit od '
            '30 minuta.',
            duration: const Duration(seconds: 5),
          );
        }

        unawaited(
          context.push<void>(AppRoutes.recordSummary, extra: session).then((
            _,
          ) {
            if (context.mounted) {
              context.read<UiBloc>().add(const UiReset());
            }
          }),
        );
      },
      child: child,
    );
  }
}
