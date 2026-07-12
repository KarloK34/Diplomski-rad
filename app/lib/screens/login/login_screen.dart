import 'package:flutter/material.dart';
import 'package:gait_sense/screens/login/login_content.dart';
import 'package:gait_sense/screens/login/login_listener.dart';
import 'package:gait_sense/screens/login/login_provider.dart';

/// Email/password + Google sign-in screen.
///
/// A top-level go_router route, unlike other non-tab screens, so the
/// router's `redirect`/`refreshListenable` auth gate can intercept
/// navigation to and from it.
class LoginScreen extends StatelessWidget {
  /// Creates the login screen.
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginProvider(
      child: LoginListener(child: LoginContent()),
    );
  }
}
