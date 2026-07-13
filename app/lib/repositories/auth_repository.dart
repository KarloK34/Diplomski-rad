import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps [FirebaseAuth] and [GoogleSignIn] behind a single account API.
///
/// Both dependencies are constructor-injectable so tests can substitute
/// fakes for the real platform channels.
///
/// `GoogleSignIn.instance.initialize` is deferred until [signInWithGoogle]
/// or [signOut] first needs it, not run eagerly in the constructor — eager
/// init would also run in widget tests, where there's no platform channel to
/// answer it.
class AuthRepository {
  /// [googleServerClientId] is the Firebase "Web client" OAuth id; required
  /// on Android so the ID token Google issues is one Firebase will accept.
  /// [googleClientId] is the iOS OAuth client id — required on iOS, which has
  /// no bundled `GoogleService-Info.plist` for the plugin to read it from.
  AuthRepository({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    this.googleServerClientId,
    this.googleClientId,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  /// The Firebase project's Google Sign-In "Web client" OAuth id.
  final String? googleServerClientId;

  /// The Firebase project's iOS OAuth client id.
  final String? googleClientId;

  Future<void>? _googleSignInInitialization;

  /// Emits the signed-in user, or null when signed out.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// The currently signed-in user, or null when signed out.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Signs in an existing account with [email] and [password].
  ///
  /// Throws [FirebaseAuthException] on failure.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Creates a new account with [email] and [password].
  ///
  /// Throws [FirebaseAuthException] on failure.
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs in via a Google account, then exchanges the resulting ID token for
  /// a Firebase credential.
  ///
  /// Throws [GoogleSignInException] if the interactive flow fails or is
  /// cancelled, [GoogleIdTokenMissingException] if it succeeds without
  /// returning an ID token, or [FirebaseAuthException] if Firebase rejects
  /// the token.
  Future<void> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();
    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw GoogleIdTokenMissingException();
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _firebaseAuth.signInWithCredential(credential);
  }

  /// Signs out of both Firebase and Google, so the account picker is shown
  /// again on the next [signInWithGoogle] call.
  ///
  /// The Google-side sign-out runs whenever the *current* Firebase user
  /// signed in with a Google credential, not just when this instance ran
  /// [signInWithGoogle] itself — the session may have been restored from a
  /// previous app run.
  Future<void> signOut() async {
    final signedInWithGoogle =
        _firebaseAuth.currentUser?.providerData.any(
          (info) => info.providerId == GoogleAuthProvider.PROVIDER_ID,
        ) ??
        false;
    await _firebaseAuth.signOut();
    if (signedInWithGoogle) {
      await _ensureGoogleSignInInitialized();
      await _googleSignIn.signOut();
    }
  }

  /// Runs [GoogleSignIn.initialize] at most once successfully, retrying on
  /// the next call if a prior attempt failed rather than caching the
  /// rejected [Future] forever.
  Future<void> _ensureGoogleSignInInitialized() async {
    try {
      await (_googleSignInInitialization ??= _googleSignIn.initialize(
        clientId: googleClientId,
        serverClientId: googleServerClientId,
      ));
    } catch (_) {
      _googleSignInInitialization = null;
      rethrow;
    }
  }
}

/// Thrown by [AuthRepository.signInWithGoogle] when the interactive flow
/// succeeds but Google returns no ID token to exchange for a Firebase
/// credential.
class GoogleIdTokenMissingException implements Exception {}
