import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_form_state.dart';
import 'package:gait_sense/blocs/auth/login_cubit.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

/// Renders the login form driven by [LoginCubit]'s state.
class LoginContent extends StatelessWidget {
  /// Creates the login content.
  const LoginContent({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Scaffold(
      body: BlocBuilder<LoginCubit, AuthFormState>(
        builder: (context, state) {
          final cubit = context.read<LoginCubit>();
          final submitting = state.status == AuthFormStatus.submitting;
          final submittingEmail =
              submitting && state.submitMethod == AuthSubmitMethod.email;
          final submittingGoogle =
              submitting && state.submitMethod == AuthSubmitMethod.google;
          return ScreenBody(
            children: [
              SizedBox(height: spacing.xl),
              const AppLogo(
                tagline: 'Istraživačka analiza aktivnosti i hoda',
              ),
              SizedBox(height: spacing.xl),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Prijava',
                      style: context.textStyles.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing.md),
                    EmailField(
                      value: state.email,
                      onChanged: cubit.emailChanged,
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: spacing.sm),
                    PasswordField(
                      value: state.password,
                      onChanged: cubit.passwordChanged,
                    ),
                    SizedBox(height: spacing.lg),
                    PrimaryButton(
                      label: 'Prijavi se',
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
                  onPressed: () => context.go(AppRoutes.signup),
                  child: const Text('Nemate račun? Registrirajte se'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
