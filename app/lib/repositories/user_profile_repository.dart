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

  /// Returns the signed-in account's stored height in centimetres, or null
  /// if unset, signed out, or the read failed — callers already treat "no
  /// height" as a normal, handled state.
  Future<double?> getHeightCm() async {
    try {
      final uid = _firebaseAuth.currentUser?.uid;
      if (uid == null) return null;
      final snapshot = await _firestore.collection('users').doc(uid).get();
      return (snapshot.data()?['heightCm'] as num?)?.toDouble();
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
  }
}
