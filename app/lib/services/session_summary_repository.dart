import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gait_sense/models/session_log.dart';

/// Syncs a lightweight per-session summary to Firestore, scoped to the
/// signed-in user.
///
/// Cadence/walking-speed estimates are deferred, not dropped — they need the
/// user's stored height and a worker isolate, which don't belong in this
/// fire-and-forget sync path.
///
/// Raw IMU samples stay local-only, keeping each synced document nowhere
/// near Firestore's 1 MiB per-document limit.
class SessionSummaryRepository {
  /// Defaults resolve lazily inside [syncSession], not here — `GaitSenseApp`
  /// constructs this unconditionally, including in widget tests that never
  /// call `Firebase.initializeApp()`, so eager access would crash them.
  SessionSummaryRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _injectedFirebaseAuth = firebaseAuth,
       _injectedFirestore = firestore;

  final FirebaseAuth? _injectedFirebaseAuth;
  final FirebaseFirestore? _injectedFirestore;

  FirebaseAuth get _firebaseAuth =>
      _injectedFirebaseAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  /// Writes a summary of [session] to `users/{uid}/sessions/{startedAt}`.
  ///
  /// No-ops if nobody is signed in — this can only happen if it races a
  /// sign-out between the recording finishing and this call running.
  Future<void> syncSession(SessionLog session) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return;

    final labelCounts = <String, int>{};
    for (final prediction in session.predictions) {
      labelCounts.update(
        prediction.label,
        (existing) => existing + 1,
        ifAbsent: () => 1,
      );
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .doc(session.startedAt.toIso8601String())
        .set({
          'startedAt': session.startedAt.toIso8601String(),
          'stoppedAt': session.stoppedAt?.toIso8601String(),
          'deviceId': session.deviceId,
          'predictionCount': session.predictions.length,
          'labelCounts': labelCounts,
        });
  }
}
