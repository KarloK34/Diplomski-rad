import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/login_cubit.dart';
import 'package:gait_sense/services/auth_repository.dart';

/// Provides a screen-scoped [LoginCubit] wired to the app's [AuthRepository].
class LoginProvider extends StatelessWidget {
  /// Wraps [child] with a freshly created [LoginCubit].
  const LoginProvider({required this.child, super.key});

  /// The subtree consuming [LoginCubit].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LoginCubit>(
      create: (context) =>
          LoginCubit(authRepository: context.read<AuthRepository>()),
      child: child,
    );
  }
}
