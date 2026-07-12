final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Returns a Croatian error message if [value] isn't a plausible
/// `local@domain.tld` shape, or `null` if it passes.
///
/// Only catches obvious typos client-side; actual deliverability is
/// confirmed server-side via Firebase Auth's verification email.
String? emailFormatError(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Unesite e-mail adresu.';
  if (!_emailShape.hasMatch(text)) return 'Unesite valjanu e-mail adresu.';
  return null;
}

/// Returns a Croatian error message if [value] is empty or shorter than the
/// 6-character minimum Firebase Auth enforces server-side, or `null` if it
/// passes.
String? passwordFormatError(String? value) {
  final text = value ?? '';
  if (text.isEmpty) return 'Unesite lozinku.';
  if (text.length < 6) return 'Lozinka mora imati barem 6 znakova.';
  return null;
}
