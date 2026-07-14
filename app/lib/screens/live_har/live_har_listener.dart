import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_bloc.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_event.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_state.dart';
import 'package:gait_sense/extensions/snackbar_context.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/screens/session_summary/session_summary_screen.dart';
import 'package:go_router/go_router.dart';

/// Handles this screen's platform-facing side effects: pushes
/// [SessionSummaryScreen] and resets [RecordingSessionBloc] back to idle on
/// return, and confirms with haptic feedback that a session actually
/// started.
class LiveHarListener extends StatelessWidget {
  /// Wraps [child] with the side effects below.
  const LiveHarListener({required this.child, super.key});

  /// The subtree rendering the current state.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<RecordingSessionBloc, RecordingSessionState>(
          // Fire once on the transition into the saved state, not on every
          // rebuild while it stays saved.
          listenWhen: (previous, current) =>
              previous.status != RecordingStatus.saved &&
              current.status == RecordingStatus.saved,
          listener: (context, state) {
            if (state.finishedSession == null) return;

            if (state.stoppedByLimit) {
              context.showSnackBar(
                'Sesija je automatski zaustavljena — dostignut je limit od '
                '30 minuta.',
                duration: const Duration(seconds: 5),
              );
            }

            unawaited(
              context.push<void>(AppRoutes.recordSummary).then((_) {
                if (!context.mounted) return;
                final bloc = context.read<RecordingSessionBloc>();
                // Deferred a frame: dispatching this immediately raced
                // go_router's own post-pop bookkeeping (it re-syncs its
                // route-information state a frame after the pop), which
                // could replay this route's push and undo the pop.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  bloc.add(const RecordingSessionReset());
                });
              }),
            );
          },
        ),
        BlocListener<RecordingSessionBloc, RecordingSessionState>(
          // The user can no longer see the screen once the phone is
          // pocketed, so this is the only confirmation that recording
          // actually started once the countdown committed.
          listenWhen: (previous, current) =>
              previous.status == RecordingStatus.preparing &&
              current.status == RecordingStatus.recording,
          listener: (context, state) => unawaited(HapticFeedback.heavyImpact()),
        ),
      ],
      child: child,
    );
  }
}
