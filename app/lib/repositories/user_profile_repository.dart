import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Persists per-account profile fields — on `users/{uid}`,
/// so they follow the signed-in account across devices
/// instead of being tied to one device's local storage.
class UserProfileRepository {
  /// [firebaseAuth]/[firestore] are injectable for tests; default to the
  /// live instances.
  UserProfileRepository({
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

  // In-memory cache, keyed by uid so a sign-out followed by a different
  // account signing in can't serve a stale height. Height changes rarely, so
  // every screen that needs it (settings, session summary) reuses this
  // instead of re-reading Firestore on every open. This repository is
  // provided once for the app's lifetime (see RepositoryProvider.value in
  // app.dart), so the cache naturally persists across screens.
  String? _cachedUid;
  double? _cachedHeightCm;

  /// Returns the signed-in account's stored height in centimetres, or null
  /// if unset, signed out, or the read failed — callers already treat "no
  /// height" as a normal, handled state.
  ///
  /// Cached in memory per [FirebaseAuth] uid after the first successful read;
  /// a failed read (network error, auth not ready yet) is deliberately left
  /// uncached so the next call retries instead of pinning "no height" for
  /// the rest of the app's lifetime.
  Future<double?> getHeightCm() async {
    try {
      final uid = _firebaseAuth.currentUser?.uid;
      if (uid == null) return null;
      if (uid == _cachedUid) return _cachedHeightCm;

      final snapshot = await _firestore.collection('users').doc(uid).get();
      final heightCm = (snapshot.data()?['heightCm'] as num?)?.toDouble();
      _cachedUid = uid;
      _cachedHeightCm = heightCm;
      return heightCm;
    } on Object {
      return null;
    }
  }

  /// Persists [heightCm] for the signed-in account. Merges so it never
  /// clobbers other fields (e.g. `onboardingCompleted`) on the same
  /// document. No-ops if nobody is signed in.
  Future<void> setHeightCm(double heightCm) async {
    assert(heightCm > 0, 'heightCm must be positive');
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set({
      'heightCm': heightCm,
    }, SetOptions(merge: true));
    _cachedUid = uid;
    _cachedHeightCm = heightCm;
  }
}
