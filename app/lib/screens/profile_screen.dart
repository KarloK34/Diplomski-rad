import 'package:flutter/material.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

/// Profile tab with user settings entry points.
class ProfileScreen extends StatelessWidget {
  /// Creates the profile screen.
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return ScreenBody(
      children: [
        const ScreenHeader(
          title: 'Profil',
          subtitle: 'Korisnički podaci, postavke i privatnost',
        ),
        SizedBox(height: spacing.lg),
        const ProfileHeaderCard(name: 'Korisnik', subtitle: 'Lokalni profil'),
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
          ],
        ),
      ],
    );
  }
}
