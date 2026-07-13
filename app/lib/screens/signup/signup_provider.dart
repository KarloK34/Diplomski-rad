import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/signup_cubit.dart';
import 'package:gait_sense/repositories/auth_repository.dart';

/// Provides a screen-scoped [SignupCubit] wired to the app's [AuthRepository].
class SignupProvider extends StatelessWidget {
  /// Wraps [child] with a freshly created [SignupCubit].
  const SignupProvider({required this.child, super.key});

  /// The subtree consuming [SignupCubit].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SignupCubit>(
      create: (context) =>
          SignupCubit(authRepository: context.read<AuthRepository>()),
      child: child,
    );
  }
}
