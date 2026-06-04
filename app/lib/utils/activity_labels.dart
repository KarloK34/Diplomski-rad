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
};

/// Returns the Croatian name for the activity [code], or the raw code when it
/// is not one of the known MotionSense classes.
String activityLabelHr(String code) => activityLabelsHr[code] ?? code;
