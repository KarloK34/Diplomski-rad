import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_cubit.dart';
import 'package:gait_sense/blocs/profile/profile_actions_cubit.dart';
import 'package:gait_sense/blocs/profile/profile_actions_state.dart';
import 'package:gait_sense/blocs/theme/theme_cubit.dart';
import 'package:gait_sense/extensions/snackbar_context.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/repositories/auth_repository.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

/// Renders the profile screen driven by [ProfileActionsCubit]'s state.
class ProfileContent extends StatelessWidget {
  /// Creates the profile content.
  const ProfileContent({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final user = context.watch<AuthCubit>().state.user;
    final displayName = user?.displayName;
    final hasDisplayName = displayName != null && displayName.trim().isNotEmpty;
    final hasPassword =
        user?.providerData.any(
          (info) => info.providerId == EmailAuthProvider.PROVIDER_ID,
        ) ??
        false;
    final actionStatus = context.watch<ProfileActionsCubit>().state.status;
    final signingOut = actionStatus == ProfileActionStatus.signingOut;
    final sendingReset = actionStatus == ProfileActionStatus.sendingReset;

    return ScreenBody(
      children: [
        const ScreenHeader(
          title: 'Profil',
          subtitle: 'Korisnički podaci, postavke i privatnost',
        ),
        SizedBox(height: spacing.lg),
        ProfileHeaderCard(
          name: hasDisplayName ? displayName : (user?.email ?? 'Korisnik'),
          subtitle: hasDisplayName
              ? (user?.email ?? 'Prijavljeni račun')
              : 'Prijavljeni račun',
          onEditTap: () => _editName(context, displayName ?? ''),
          avatarUrl: user?.photoURL,
        ),
        SizedBox(height: spacing.md),
        InfoCard(
          title: 'Izgled aplikacije',
          rows: [
            Padding(
              padding: EdgeInsets.only(top: spacing.sm),
              child: ThemeModeSelector(
                value: context.watch<ThemeCubit>().state,
                onChanged: (mode) =>
                    context.read<ThemeCubit>().setThemeMode(mode),
              ),
            ),
          ],
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
            if (hasPassword)
              NavigationListTile(
                icon: Icons.lock_reset,
                title: 'Promjena lozinke',
                subtitle: 'Poslat ćemo vezu na e-poštu',
                showChevron: false,
                loading: sendingReset,
                onTap: () => _sendPasswordReset(context, user?.email),
              ),
            NavigationListTile(
              icon: Icons.lock_outline,
              title: 'Privatnost',
              subtitle: 'Lokalna obrada podataka',
              onTap: () => context.push(AppRoutes.profilePrivacy),
            ),
            NavigationListTile(
              icon: Icons.info_outline,
              title: 'O aplikaciji',
              subtitle: 'Gait Sense MVP',
              onTap: () => context.push(AppRoutes.profileAbout),
            ),
            NavigationListTile(
              icon: Icons.logout,
              title: 'Odjava',
              showChevron: false,
              loading: signingOut,
              onTap: () => _confirmSignOut(context),
            ),
          ],
        ),
      ],
    );
  }
}

/// Opens the edit-name dialog seeded with [currentName], then persists a
/// non-empty result. `AuthCubit` listens to `userChanges()` (not
/// `authStateChanges()`) specifically so this update re-emits and refreshes
/// the header without any extra wiring here.
Future<void> _editName(BuildContext context, String currentName) async {
  final newName = await showEditNameDialog(context, initialValue: currentName);
  if (newName == null || newName.isEmpty || !context.mounted) return;

  try {
    await context.read<AuthRepository>().updateDisplayName(newName);
  } on Object {
    if (context.mounted) {
      context.showSnackBar('Spremanje nije uspjelo. Pokušajte ponovo.');
    }
  }
}

/// Confirms before sending a password-reset link to [email] — only shown
/// for password-provider accounts, since Google-only accounts have no
/// password to reset.
Future<void> _sendPasswordReset(BuildContext context, String? email) async {
  if (email == null) return;
  final confirmed = await showConfirmationDialog(
    context,
    title: 'Promjena lozinke?',
    message: 'Poslat ćemo vezu za promjenu lozinke na $email.',
    confirmLabel: 'Pošalji',
  );
  if (!confirmed || !context.mounted) return;

  await context.read<ProfileActionsCubit>().sendPasswordReset(email);
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

  await context.read<ProfileActionsCubit>().signOut();
}
