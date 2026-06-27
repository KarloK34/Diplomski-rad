import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/ui/ui_bloc.dart';
import 'package:gait_sense/screens/live_har_screen.dart';
import 'package:gait_sense/services/gait_foreground_service.dart';
import 'package:gait_sense/services/session_log_repository.dart';
import 'package:gait_sense/services/user_preferences_repository.dart';

/// Root MaterialApp and composition root.
///
/// Owns the single [GaitForegroundService] (UI-isolate side),
/// [SessionLogRepository], and [UserPreferencesRepository] for the app's
/// lifetime and hands them to the screens that need them.  The provider sits
/// above [MaterialApp] so the bloc is reachable from every pushed route.
class GaitSenseApp extends StatefulWidget {
  /// Default constructor.
  const GaitSenseApp({super.key});

  @override
  State<GaitSenseApp> createState() => _GaitSenseAppState();
}

class _GaitSenseAppState extends State<GaitSenseApp> {
  final GaitForegroundService _service = GaitForegroundService();
  final SessionLogRepository _repository = SessionLogRepository();
  final UserPreferencesRepository _preferences = UserPreferencesRepository();

  @override
  void initState() {
    super.initState();
    // Configures the notification channel and task options once at startup.
    _service.init();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UiBloc>(
      create: (_) => UiBloc(controller: _service, repository: _repository),
      child: RepositoryProvider<UserPreferencesRepository>.value(
        value: _preferences,
        child: MaterialApp(
          title: 'Gait Sense',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            useMaterial3: true,
          ),
          home: const LiveHarScreen(),
        ),
      ),
    );
  }
}
