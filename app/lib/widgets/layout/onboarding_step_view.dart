import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// One visual + title + description step, used by the onboarding carousel
/// and by the on-demand placement-instructions reminder so the two never
/// drift apart in wording.
class OnboardingStepView extends StatelessWidget {
  /// Creates the step from [title] and [description], visualized by
  /// exactly one of [icon] or [imageAsset].
  const OnboardingStepView({
    required this.title,
    required this.description,
    this.icon,
    this.imageAsset,
    super.key,
  }) : assert(
         (icon == null) != (imageAsset == null),
         'Provide exactly one of icon or imageAsset.',
       );

  /// Icon shown above the title, inside a filled circle.
  final IconData? icon;

  /// Illustration asset shown above the title instead of [icon].
  final String? imageAsset;

  /// Step heading.
  final String title;

  /// Supporting body text.
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (imageAsset != null)
            _Illustration(assetPath: imageAsset!)
          else
            _IconBadge(icon: icon!),
          SizedBox(height: spacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.textStyles.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: spacing.sm),
          Text(
            description,
            textAlign: TextAlign.center,
            style: context.textStyles.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 44, color: colors.onPrimaryContainer),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.radii.xl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Image.asset(assetPath, height: 160, fit: BoxFit.contain),
    );
  }
}
