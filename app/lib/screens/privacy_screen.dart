import 'package:flutter/material.dart';
import 'package:gait_sense/widgets/widgets.dart';

/// Explains what the app processes on-device versus what syncs to the cloud.
class PrivacyScreen extends StatelessWidget {
  /// Creates the privacy screen.
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoScreenScaffold(
      title: 'Privatnost',
      children: [
        InfoSection(
          title: 'Obrada na uređaju',
          body:
              'Uzorkovanje senzora (akcelerometar i žiroskop) te klasifikacija '
              'aktivnosti pomoću TFLite modela odvijaju se isključivo na vašem '
              'uređaju. Sirovi senzorski podaci nikada se ne šalju u oblak.',
        ),
        InfoSection(
          title: 'Podaci u oblaku',
          body:
              'Uz vaš račun u oblaku se pohranjuju samo visina i sažeci '
              'sesija — trajanje, broj koraka i dominantna aktivnost — '
              'nikada sirovi senzorski podaci. Ovi podaci omogućuju pregled '
              'povijesti i trendova te sinkronizaciju između uređaja.',
        ),
        InfoSection(
          title: 'Izgled aplikacije',
          body:
              'Postavka svijetle/tamne teme sprema se lokalno na uređaju i ne '
              'sinkronizira se s računom.',
        ),
      ],
    );
  }
}
