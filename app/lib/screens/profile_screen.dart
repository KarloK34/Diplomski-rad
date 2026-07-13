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
class ProfileScreen extends StatelessWidget {
  /// Creates the profile screen.
  const ProfileScreen({super.key});

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
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await context.read<AuthRepository>().signOut();
    } on Object {
      if (context.mounted) {
        context.showSnackBar('Odjava nije uspjela. Pokušajte ponovo.');
      }
    }
  }
}
