import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_form_state.dart';
import 'package:gait_sense/blocs/auth/signup_cubit.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

/// Renders the registration form driven by [SignupCubit]'s state.
class SignupContent extends StatelessWidget {
  /// Creates the signup content.
  const SignupContent({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Scaffold(
      body: BlocBuilder<SignupCubit, AuthFormState>(
        builder: (context, state) {
          final cubit = context.read<SignupCubit>();
          final submitting = state.status == AuthFormStatus.submitting;
          final submittingEmail =
              submitting && state.submitMethod == AuthSubmitMethod.email;
          final submittingGoogle =
              submitting && state.submitMethod == AuthSubmitMethod.google;
          return ScreenBody(
            children: [
              SizedBox(height: spacing.xl),
              const AppLogo(
                tagline: 'Biomehanička analiza na dohvat ruke',
              ),
              SizedBox(height: spacing.xl),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Registracija',
                      style: context.textStyles.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing.md),
                    EmailField(
                      value: state.email,
                      onChanged: cubit.emailChanged,
                    ),
                    SizedBox(height: spacing.sm),
                    PasswordField(
                      value: state.password,
                      onChanged: cubit.passwordChanged,
                    ),
                    SizedBox(height: spacing.lg),
                    PrimaryButton(
                      label: 'Registriraj se',
                      onPressed: submitting ? null : cubit.submitted,
                      loading: submittingEmail,
                    ),
                    SizedBox(height: spacing.sm),
                    GoogleSignInButton(
                      onPressed: submitting
                          ? null
                          : cubit.googleSignInRequested,
                      loading: submittingGoogle,
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing.lg),
              Center(
                child: TextButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Već imate račun? Prijavite se'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
