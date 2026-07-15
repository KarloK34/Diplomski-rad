import 'package:flutter/material.dart';
import 'package:gait_sense/widgets/widgets.dart';

/// Final onboarding page: an optional, skippable height entry so the
/// walking-speed estimate (Zijlstra & Hof, 2003) works from the very first
/// recorded session.
class OnboardingHeightPage extends StatelessWidget {
  /// Creates the height page bound to [formKey] and [controller].
  const OnboardingHeightPage({
    required this.formKey,
    required this.controller,
    super.key,
  });

  /// Form key used by the parent to validate before finishing onboarding.
  final GlobalKey<FormState> formKey;

  /// Controller holding the entered height, read by the parent on finish.
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepView(
      icon: Icons.straighten,
      title: 'Za precizniju procjenu hoda',
      description:
          'Visina se koristi za procjenu duljine koraka i brzine hoda. '
          'Možete ju unijeti i kasnije, u postavkama.',
      child: Form(
        key: formKey,
        child: HeightField(controller: controller, required: false),
      ),
    );
  }
}
