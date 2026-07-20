import 'package:flutter/material.dart';
import 'package:gait_sense/screens/profile/profile_content.dart';
import 'package:gait_sense/screens/profile/profile_listener.dart';
import 'package:gait_sense/screens/profile/profile_provider.dart';

/// Profile tab with account info and settings entry points.
class ProfileScreen extends StatelessWidget {
  /// Creates the profile screen.
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileProvider(
      child: ProfileListener(child: ProfileContent()),
    );
  }
}
