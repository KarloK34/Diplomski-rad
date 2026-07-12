import 'package:firebase_auth/firebase_auth.dart';

/// Maps a sign-in [error] to a Croatian message.
///
/// `invalid-credential` covers both wrong password and unknown email
/// (current Firebase Auth avoids revealing which); `user-not-found`/
/// `wrong-password` remain as a fallback for older backend responses.
String loginErrorMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-credential' ||
    'user-not-found' ||
    'wrong-password' => 'Neispravna e-mail adresa ili lozinka.',
    'invalid-email' => 'Unesena e-mail adresa nije valjana.',
    'user-disabled' => 'Ovaj račun je onemogućen.',
    'too-many-requests' => 'Previše pokušaja. Pokušajte ponovno kasnije.',
    _ => 'Prijava nije uspjela. Pokušajte ponovno.',
  };
}

/// Maps a registration [error] to a Croatian message.
String signupErrorMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'email-already-in-use' => 'Račun s ovom e-mail adresom već postoji.',
    'invalid-email' => 'Unesena e-mail adresa nije valjana.',
    'weak-password' => 'Lozinka je preslaba. Odaberite jaču lozinku.',
    'operation-not-allowed' =>
      'Registracija e-mailom trenutno nije omogućena.',
    _ => 'Registracija nije uspjela. Pokušajte ponovno.',
  };
}
