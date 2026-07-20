import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/repositories/theme_preference_repository.dart';

/// Tracks the device's light/dark/system theme choice.
class ThemeCubit extends Cubit<ThemeMode> {
  /// Starts at [ThemeMode.system] and loads the saved preference
  /// asynchronously — resolved lazily rather than in a constructor
  /// `await`, so widget tests that never touch shared_preferences still
  /// build.
  ThemeCubit({required ThemePreferenceRepository repository})
    : this._(repository);

  ThemeCubit._(this._repository) : super(ThemeMode.system) {
    unawaited(_load());
  }

  final ThemePreferenceRepository _repository;

  Future<void> _load() async {
    final mode = await _repository.getThemeMode();
    if (isClosed) return;
    emit(mode);
  }

  /// Switches to [mode] immediately, then persists it.
  Future<void> setThemeMode(ThemeMode mode) async {
    emit(mode);
    await _repository.setThemeMode(mode);
  }
}
