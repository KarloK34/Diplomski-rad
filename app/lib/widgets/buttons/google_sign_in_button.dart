import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// "Continue with Google" button, shared by the login and signup screens.
///
/// Shows a spinner instead of its icon/label while [loading], disabling
/// itself so it can't be tapped twice.
class GoogleSignInButton extends StatelessWidget {
  /// Creates the button, calling [onPressed] on tap.
  const GoogleSignInButton({
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  /// Called when the button is tapped. Null disables the button.
  final VoidCallback? onPressed;

  /// Whether to show a spinner and disable the button.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.primary,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icons/google_logo.svg',
                    width: 18,
                    height: 18,
                  ),
                  SizedBox(width: context.spacing.xs),
                  const Text('Nastavi putem Google računa'),
                ],
              ),
      ),
    );
  }
}
