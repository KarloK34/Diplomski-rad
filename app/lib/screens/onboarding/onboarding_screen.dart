import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_cubit.dart';
import 'package:gait_sense/blocs/onboarding/onboarding_cubit.dart';
import 'package:gait_sense/screens/live_har/recording_placement_copy.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/widgets.dart';

/// Shown once per account, right after first sign-in — a 3-step introduction
/// to what the app does, how to place the phone for a good session, and what
/// permissions it will ask for.
///
/// Paging is plain presentation state with no business logic, so this is a
/// `StatefulWidget` holding a `PageController` directly rather than a Cubit —
/// only the account-level completion flag ([OnboardingCubit]) warrants one.
class OnboardingScreen extends StatefulWidget {
  /// Creates the onboarding screen.
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _pageCount = 3;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_currentPage == _pageCount - 1) {
      _finish();
      return;
    }
    unawaited(
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      ),
    );
  }

  void _finish() {
    final uid = context.read<AuthCubit>().state.user?.uid;
    if (uid == null) return;
    unawaited(context.read<OnboardingCubit>().markCompleted(uid));
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final isLastPage = _currentPage == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: const [
                  _WelcomePage(),
                  OnboardingStepView(
                    imageAsset: RecordingPlacementCopy.imageAsset,
                    title: RecordingPlacementCopy.title,
                    description: RecordingPlacementCopy.description,
                  ),
                  OnboardingStepView(
                    icon: Icons.notifications_active_outlined,
                    title: 'Spremni za početak',
                    description:
                        'Aplikacija će tražiti dopuštenje za notifikacije i '
                        'izuzeće od baterijske optimizacije — potrebno '
                        'za pouzdano snimanje dok je ekran isključen. Ove '
                        'upute možete ponovno pogledati bilo kada preko '
                        'ikone info na kartici Snimanje.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(spacing.lg),
              child: Column(
                children: [
                  OnboardingDotsIndicator(
                    count: _pageCount,
                    currentIndex: _currentPage,
                  ),
                  SizedBox(height: spacing.lg),
                  PrimaryButton(
                    label: isLastPage ? 'Idi na početnu' : 'Dalje',
                    onPressed: _goToNextPage,
                  ),
                  Visibility(
                    visible: !isLastPage,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Padding(
                      padding: EdgeInsets.only(top: spacing.sm),
                      child: SecondaryButton(
                        label: 'Preskoči',
                        onPressed: _finish,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// First onboarding page: brand mark, personal greeting, and a short
/// value-prop paragraph.
class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

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
