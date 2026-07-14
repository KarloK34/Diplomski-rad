import 'package:cloud_firestore/cloud_firestore.dart';

/// Persists whether an account has completed onboarding, scoped to the
/// account rather than the device — so re-installing or signing in on a new
/// device doesn't show onboarding again.
class OnboardingRepository {
  /// [firestore] is injectable for tests; defaults to the live instance.
  OnboardingRepository({FirebaseFirestore? firestore})
    : _injectedFirestore = firestore;

  final FirebaseFirestore? _injectedFirestore;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  /// Whether [uid] has completed onboarding. False if the document or field
  /// doesn't exist yet — the default for any account that hasn't finished it.
  Future<bool> isCompleted(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    return snapshot.data()?['onboardingCompleted'] as bool? ?? false;
  }

  /// Marks [uid] as having completed onboarding. Merges so it never clobbers
  /// other fields on the same user document.
  Future<void> markCompleted(String uid) async {
    await _firestore.collection('users').doc(uid).set({
      'onboardingCompleted': true,
    }, SetOptions(merge: true));
  }
}
