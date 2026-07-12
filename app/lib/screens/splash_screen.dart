import 'package:flutter/material.dart';

/// Shown while sign-in status is `AuthStatus.unknown`, so the router's
/// redirect has somewhere neutral to point at instead of flashing the login
/// screen for an already signed-in user on cold start.
class SplashScreen extends StatelessWidget {
  /// Creates the splash screen.
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
