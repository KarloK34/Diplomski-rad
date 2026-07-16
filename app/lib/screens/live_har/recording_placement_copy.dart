/// Shared copy for "how to place the phone for a good session" — shown both
/// as onboarding's second step and as the record tab's on-demand reminder, so
/// the wording can't drift between the two.
class RecordingPlacementCopy {
  const RecordingPlacementCopy._();

  /// Illustration shown alongside the copy.
  static const String imageAsset =
      'assets/illustrations/phone_pocket_placement.png';

  /// Step/screen heading.
  static const String title = 'Kako snimiti dobru sesiju';

  /// Body text explaining phone placement and the start countdown.
  static const String description =
      'Mobitel držite uspravno, u prednjem džepu hlača na bedru. Koristite '
      'hlače sa što užim džepom kako bi smanjili pomicanje mobitela unutar '
      'džepa. Nakon što pritisnete Start, imate nekoliko sekundi da ga '
      'spremite u džep — vibracija javlja kad snimanje stvarno počne. '
      'Ekran slobodno zaključajte — snimanje se nastavlja u pozadini, '
      'a zaključan ekran sprječava slučajne dodire iz džepa.';
}
