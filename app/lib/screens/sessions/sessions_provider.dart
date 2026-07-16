import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/sessions_list/sessions_list_cubit.dart';

/// Provides a screen-scoped [SessionsListCubit] for the Sessions tab's
/// filter/pagination UI state.
class SessionsProvider extends StatelessWidget {
  /// Wraps [child] with a freshly created [SessionsListCubit].
  const SessionsProvider({required this.child, super.key});

  /// The subtree consuming [SessionsListCubit].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SessionsListCubit>(
      create: (_) => SessionsListCubit(),
      child: child,
    );
  }
}
