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

/// Returns a Croatian error message if [value] is empty after trimming, or
/// `null` if it passes. [fieldName] is the lowercase noun used in the
/// message, e.g. `"ime"` or `"prezime"`.
String? requiredNameError(String? value, String fieldName) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Unesite $fieldName.';
  return null;
}

/// Returns a Croatian error message if [value] isn't a whole number of
/// centimetres in the plausible adult range, or `null` if it passes. An
/// empty value passes when [required] is false — used by the skippable
/// onboarding height step.
String? heightRangeError(String? value, {bool required = true}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty && !required) return null;
  final v = int.tryParse(text);
  if (v == null) return 'Unesite broj.';
  if (v < 100 || v > 230) return 'Unesite visinu između 100 i 230 cm.';
  return null;
}
