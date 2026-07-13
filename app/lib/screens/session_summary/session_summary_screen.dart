import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/repositories/user_preferences_repository.dart';
import 'package:gait_sense/screens/session_summary/session_summary_computation.dart';
import 'package:gait_sense/screens/session_summary/session_summary_content.dart';
import 'package:gait_sense/screens/session_summary/session_summary_error_view.dart';
import 'package:gait_sense/screens/session_summary/session_summary_loading_view.dart';

/// Read-only summary of a finished recording session.
///
/// Heavy aggregation (class totals, timeline, gait cadence) is offloaded to a
/// worker isolate via [compute] so the UI thread is never blocked, even for
/// sessions that accumulated tens of thousands of raw IMU samples.
class SessionSummaryScreen extends StatefulWidget {
  /// Creates the summary screen for [session].
  const SessionSummaryScreen({required this.session, super.key});

  /// The finished session to summarize.
  final SessionLog session;

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  late final Future<SessionSummaryData> _summaryFuture;

  Future<SessionSummaryInput> _buildInput() async {
    final prefs = context.read<UserPreferencesRepository>();
    final heightCm = await prefs.getHeightCm();
    return SessionSummaryInput(
      session: widget.session,
      userHeightCm: heightCm,
    );
  }

  @override
  void initState() {
    super.initState();
    // Read the user height (fast local read), then dispatch the heavy
    // computation to a worker isolate — stored so Flutter does not
    // re-submit it on rebuilds.
    _summaryFuture = _buildInput().then(
      (input) => compute(computeSessionSummaryData, input),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SessionSummaryData>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SessionSummaryErrorView(error: snapshot.error!);
        }
        if (!snapshot.hasData) {
          return const SessionSummaryLoadingView();
        }
        return SessionSummaryContent(
          session: widget.session,
          data: snapshot.data!,
        );
      },
    );
  }
}
