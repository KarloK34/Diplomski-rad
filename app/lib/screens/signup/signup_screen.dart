import 'package:flutter/material.dart';
import 'package:gait_sense/screens/signup/signup_content.dart';
import 'package:gait_sense/screens/signup/signup_listener.dart';
import 'package:gait_sense/screens/signup/signup_provider.dart';

/// Email/password + Google registration screen.
///
/// A top-level go_router route for the same reason as `LoginScreen`: the
/// router's auth gate only intercepts go_router-managed navigation.
class SignupScreen extends StatelessWidget {
  /// Creates the signup screen.
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SignupProvider(
      child: SignupListener(child: SignupContent()),
    );
  }
}
