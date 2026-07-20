import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/profile/profile_actions_cubit.dart';
import 'package:gait_sense/repositories/auth_repository.dart';

/// Provides a screen-scoped [ProfileActionsCubit] wired to the app's
/// [AuthRepository].
class ProfileProvider extends StatelessWidget {
  /// Wraps [child] with a freshly created [ProfileActionsCubit].
  const ProfileProvider({required this.child, super.key});

  /// The subtree consuming [ProfileActionsCubit].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileActionsCubit>(
      create: (context) =>
          ProfileActionsCubit(authRepository: context.read<AuthRepository>()),
      child: child,
    );
  }
}
