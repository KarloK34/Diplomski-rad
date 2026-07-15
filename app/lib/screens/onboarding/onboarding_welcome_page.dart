import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_cubit.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/widgets.dart';

/// First onboarding page: brand mark, personal greeting, and a short
/// value-prop paragraph.
class OnboardingWelcomePage extends StatelessWidget {
  /// Creates the welcome page.
  const OnboardingWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final firstName = _firstNameFrom(
      context.watch<AuthCubit>().state.user?.displayName,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppLogo(
            tagline: 'Analiza hoda pomoću senzora vašeg telefona',
          ),
          SizedBox(height: spacing.lg),
          if (firstName != null) ...[
            Text(
              'Bok, $firstName!',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: spacing.xs),
          ],
          Text(
            'Gait Sense prati vaš hod izravno na uređaju. U slijedećih '
            'nekoliko koraka objašnjeno je kako snimiti sesiju koja daje '
            'najkvalitetnije rezultate.',
            textAlign: TextAlign.center,
            style: context.textStyles.bodyLarge?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Takes the first token of a Firebase [displayName] ("Ana Anić" → "Ana"),
/// or null if there is no name to greet with.
String? _firstNameFrom(String? displayName) {
  final trimmed = displayName?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.split(RegExp(r'\s+')).first;
}
