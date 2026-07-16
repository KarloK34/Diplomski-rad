/// Human-readable Croatian names for the model's activity class codes.
///
/// The codes are the MotionSense activity abbreviations as documented in the
/// dataset (Malekzadeh et al., "Mobile Sensor Data Anonymization", IoTDI 2019,
/// https://doi.org/10.1145/3302505.3310068): dws/ups = walking down/up stairs,
/// wlk = walking, jog = jogging, std = standing, sit = sitting.
const Map<String, String> activityLabelsHr = <String, String>{
  'dws': 'Niz stepenice',
  'ups': 'Uz stepenice',
  'wlk': 'Hodanje',
  'jog': 'Trčanje',
  'std': 'Stajanje',
  'sit': 'Sjedenje',
  restingActivityCode: 'Mirovanje',
};

/// Display-only code standing in for `std`+`sit` merged together: the model
/// still classifies both separately, but they're both near-static from
/// phone-IMU data alone, so raw predictions flip between them noisily and
/// gait analysis doesn't need the distinction. Used wherever the app
/// aggregates predictions for display; kept separate in the raw/smoothed HAR
/// diagnostics on the session quality section.
const String restingActivityCode = 'rest';

/// Raw model codes collapsed into [restingActivityCode] for display.
const Set<String> restingActivityLabels = {'std', 'sit'};

/// Maps [code] to [restingActivityCode] when it is one of
/// [restingActivityLabels], otherwise returns [code] unchanged.
String displayActivityCode(String code) =>
    restingActivityLabels.contains(code) ? restingActivityCode : code;

/// Returns the Croatian name for the activity [code], or the raw code when it
/// is not one of the known MotionSense classes.
String activityLabelHr(String code) => activityLabelsHr[code] ?? code;
