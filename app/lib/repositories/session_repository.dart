import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:gait_sense/models/session_summary_record.dart';

/// Reads and writes cloud-synced session summaries, scoped to the signed-in
/// account under `users/{uid}/sessions/{startedAt}`.
///
/// Raw IMU samples are never written here — they stay in the on-device session
/// log — so each document stays well under Firestore's 1 MiB limit. Writes are
/// served from the offline cache immediately and queued for sync by the SDK.
class SessionRepository {
  /// Defaults resolve lazily inside each method, not in the constructor:
  /// `GaitSenseApp` builds this unconditionally, including in widget tests that
  /// never call `Firebase.initializeApp()`, so eager access would crash them.
  SessionRepository({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _injectedFirebaseAuth = firebaseAuth,
      _injectedFirestore = firestore;

  final FirebaseAuth? _injectedFirebaseAuth;
  final FirebaseFirestore? _injectedFirestore;

  FirebaseAuth get _firebaseAuth =>
      _injectedFirebaseAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>? _sessionsRef() {
    // Fails open when Firebase isn't available (e.g. widget tests that never
    // call Firebase.initializeApp): callers then no-op or emit an empty list,
    // matching UserProfileRepository's behavior.
    try {
      final uid = _firebaseAuth.currentUser?.uid;
      if (uid == null) return null;
      return _firestore.collection('users').doc(uid).collection('sessions');
    } on Object {
      return null;
    }
  }

  /// Persists [record] at `users/{uid}/sessions/{record.id}`.
  ///
  /// No-ops if nobody is signed in — only possible if this races a sign-out.
  Future<void> saveSession(SessionSummaryRecord record) async {
    final ref = _sessionsRef();
    if (ref == null) return;
    await ref.doc(record.id).set(record.toJson());
  }

  /// Streams the account's sessions, newest first.
  ///
  /// Emits an empty list when signed out. Malformed documents are skipped
  /// rather than breaking the whole stream.
  Stream<List<SessionSummaryRecord>> watchSessions() {
    final ref = _sessionsRef();
    if (ref == null) return Stream.value(const []);
    return ref.orderBy('startedAt', descending: true).snapshots().map((
      snapshot,
    ) {
      final records = <SessionSummaryRecord>[];
      for (final doc in snapshot.docs) {
        try {
          records.add(SessionSummaryRecord.fromJson(doc.data()));
        } on Object catch (error) {
          debugPrint('Skipping unreadable session ${doc.id}: $error');
        }
      }
      return records;
    });
  }

  /// Deletes the session whose start time is [startedAtIso].
  Future<void> deleteSession(String startedAtIso) async {
    final ref = _sessionsRef();
    if (ref == null) return;
    await ref.doc(startedAtIso).delete();
  }
}
