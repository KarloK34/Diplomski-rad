import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/app_dependencies.dart';
import 'package:gait_sense/blocs/auth/auth_cubit.dart';
import 'package:gait_sense/blocs/onboarding/onboarding_cubit.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_bloc.dart';
import 'package:gait_sense/repositories/auth_repository.dart';
import 'package:gait_sense/repositories/session_log_repository.dart';
import 'package:gait_sense/repositories/user_profile_repository.dart';
import 'package:gait_sense/theme/gait_sense_theme.dart';

/// Root MaterialApp — see [AppDependencies] for the singletons provided
/// above it so they're reachable from every pushed route.
class GaitSenseApp extends StatefulWidget {
  /// [authRepository] is overridable so tests can substitute a fake instead
  /// of touching real Firebase.
  const GaitSenseApp({this.authRepository, super.key});

  /// Overrides the app's [AuthRepository]; defaults to a real one.
  final AuthRepository? authRepository;

  @override
  State<GaitSenseApp> createState() => _GaitSenseAppState();
}

class _GaitSenseAppState extends State<GaitSenseApp> {
  late final AppDependencies _dependencies = AppDependencies(
    authRepository: widget.authRepository,
  );

  @override
  void initState() {
    super.initState();
    _dependencies.init();
  }

  @override
  void dispose() {
    _dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(
          value: _dependencies.authRepository,
        ),
        RepositoryProvider<UserProfileRepository>.value(
          value: _dependencies.userProfileRepository,
        ),
        RepositoryProvider<SessionLogRepository>.value(
          value: _dependencies.sessionLogRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: _dependencies.authCubit),
          BlocProvider<OnboardingCubit>.value(
            value: _dependencies.onboardingCubit,
          ),
          BlocProvider<RecordingSessionBloc>.value(
            value: _dependencies.recordingSessionBloc,
          ),
        ],
        child: MaterialApp.router(
          title: 'Gait Sense',
          theme: GaitSenseTheme.light(),
          darkTheme: GaitSenseTheme.dark(),
          routerConfig: _dependencies.router,
        ),
      ),
    );
  }
}
