import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_cubit.dart';
import 'package:gait_sense/blocs/onboarding/onboarding_cubit.dart';
import 'package:gait_sense/repositories/user_profile_repository.dart';
import 'package:gait_sense/screens/live_har/recording_placement_copy.dart';
import 'package:gait_sense/screens/onboarding/onboarding_height_page.dart';
import 'package:gait_sense/screens/onboarding/onboarding_welcome_page.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/widgets.dart';

/// Shown once per account, right after first sign-in — a 4-step introduction
/// to what the app does, how to place the phone for a good session, what
/// permissions it will ask for, and an optional body height for the
/// walking-speed estimate.
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
  static const int _pageCount = 4;

  final PageController _pageController = PageController();
  final GlobalKey<FormState> _heightFormKey = GlobalKey<FormState>();
  final TextEditingController _heightController = TextEditingController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_currentPage == _pageCount - 1) {
      if (!(_heightFormKey.currentState?.validate() ?? true)) return;
      unawaited(_finish());
      return;
    }
    unawaited(
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _finish() async {
    final uid = context.read<AuthCubit>().state.user?.uid;
    if (uid == null) return;

    final heightCm = int.tryParse(_heightController.text.trim());
    if (heightCm != null) {
      try {
        await context.read<UserProfileRepository>().setHeightCm(
          heightCm.toDouble(),
        );
      } on Object {
        // Non-fatal: the user can still set height later from Settings.
      }
    }

    if (!mounted) return;
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
                children: [
                  const OnboardingWelcomePage(),
                  const OnboardingStepView(
                    imageAsset: RecordingPlacementCopy.imageAsset,
                    title: RecordingPlacementCopy.title,
                    description: RecordingPlacementCopy.description,
                  ),
                  OnboardingHeightPage(
                    formKey: _heightFormKey,
                    controller: _heightController,
                  ),
                  const OnboardingStepView(
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
