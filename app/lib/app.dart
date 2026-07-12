import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_cubit.dart';
import 'package:gait_sense/blocs/ui/ui_bloc.dart';
import 'package:gait_sense/firebase_options.dart';
import 'package:gait_sense/navigation/app_router.dart';
import 'package:gait_sense/navigation/go_router_refresh_stream.dart';
import 'package:gait_sense/services/auth_repository.dart';
import 'package:gait_sense/services/gait_foreground_service.dart';
import 'package:gait_sense/services/session_log_repository.dart';
import 'package:gait_sense/services/session_summary_repository.dart';
import 'package:gait_sense/services/user_preferences_repository.dart';
import 'package:gait_sense/theme/gait_sense_theme.dart';
import 'package:go_router/go_router.dart';

/// Root MaterialApp and composition root — owns the app's singleton
/// services/repositories and provides them above [MaterialApp] so they're
/// reachable from every pushed route.
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
  final GaitForegroundService _service = GaitForegroundService();
  final SessionLogRepository _repository = SessionLogRepository();
  final UserPreferencesRepository _preferences = UserPreferencesRepository();
  final SessionSummaryRepository _summaryRepository =
      SessionSummaryRepository();
  // The Firebase project's auto-generated "Web client" OAuth id (from
  // android/app/google-services.json's oauth_client, client_type 3) — needed
  // so the ID token Google issues on Android is one Firebase will accept.
  late final AuthRepository _authRepository =
      widget.authRepository ??
      AuthRepository(
        googleServerClientId:
            // The OAuth client id itself can't be wrapped.
            // ignore: lines_longer_than_80_chars
            '900038882223-8ur8ge2s5duga2a801nkjassp8pu7pt8.apps.googleusercontent.com',
        // iOS has no bundled GoogleService-Info.plist, so the client id has
        // to be supplied at runtime from the FlutterFire-generated options.
        googleClientId: defaultTargetPlatform == TargetPlatform.iOS
            ? DefaultFirebaseOptions.ios.iosClientId
            : null,
      );
  late final AuthCubit _authCubit = AuthCubit(
    authRepository: _authRepository,
  );
  late final UiBloc _uiBloc = UiBloc(
    controller: _service,
    repository: _repository,
    summaryRepository: _summaryRepository,
  );
  // Held as a field (rather than passed inline to createAppRouter) so
  // dispose() can reach it — go_router's own dispose only removes its
  // listener, it never calls dispose() on the Listenable it was given.
  late final GoRouterRefreshStream _refreshListenable = GoRouterRefreshStream(
    [_authCubit.stream, _uiBloc.stream],
  );
  late final GoRouter _router = createAppRouter(
    authCubit: _authCubit,
    refreshListenable: _refreshListenable,
  );

  @override
  void initState() {
    super.initState();
    _service.init();
  }

  @override
  void dispose() {
    _router.dispose();
    _refreshListenable.dispose();
    unawaited(_authCubit.close());
    unawaited(_uiBloc.close());
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<AuthRepository>.value(
      value: _authRepository,
      child: BlocProvider<AuthCubit>.value(
        value: _authCubit,
        child: BlocProvider<UiBloc>.value(
          value: _uiBloc,
          child: RepositoryProvider<UserPreferencesRepository>.value(
            value: _preferences,
            child: MaterialApp.router(
              title: 'Gait Sense',
              theme: GaitSenseTheme.light(),
              darkTheme: GaitSenseTheme.dark(),
              routerConfig: _router,
            ),
          ),
        ),
      ),
    );
  }
}
