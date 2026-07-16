import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_cubit.dart';
import 'package:gait_sense/extensions/snackbar_context.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/repositories/auth_repository.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

/// Profile tab with account info and settings entry points.
class ProfileScreen extends StatefulWidget {
  /// Creates the profile screen.
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _signingOut = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final user = context.watch<AuthCubit>().state.user;
    return ScreenBody(
      children: [
        const ScreenHeader(
          title: 'Profil',
          subtitle: 'Korisnički podaci, postavke i privatnost',
        ),
        SizedBox(height: spacing.lg),
        ProfileHeaderCard(
          name: user?.email ?? 'Korisnik',
          subtitle: 'Prijavljeni račun',
        ),
        SizedBox(height: spacing.md),
        DividedListCard(
          items: [
            NavigationListTile(
              icon: Icons.straighten,
              title: 'Parametri tijela',
              subtitle: 'Visina za procjenu hoda',
              onTap: () => context.push(AppRoutes.profileSettings),
            ),
            const NavigationListTile(
              icon: Icons.lock_outline,
              title: 'Privatnost',
              subtitle: 'Lokalna obrada podataka',
              showChevron: false,
            ),
            const NavigationListTile(
              icon: Icons.info_outline,
              title: 'O aplikaciji',
              subtitle: 'Gait Sense MVP',
              showChevron: false,
            ),
            NavigationListTile(
              icon: Icons.logout,
              title: 'Odjava',
              showChevron: false,
              loading: _signingOut,
              onTap: () => _confirmSignOut(context),
            ),
          ],
        ),
      ],
    );
  }

  /// Confirms the destructive action before signing out, since it ends the
  /// session and requires signing back in to resume.
  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Odjava?',
      message: 'Morat ćete se ponovo prijaviti za nastavak korištenja.',
      confirmLabel: 'Odjavi se',
    );
    if (!confirmed || !context.mounted) return;

    setState(() => _signingOut = true);
    try {
      await context.read<AuthRepository>().signOut();
    } on Object {
      if (context.mounted) {
        context.showSnackBar('Odjava nije uspjela. Pokušajte ponovo.');
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }
}
