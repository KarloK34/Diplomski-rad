import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Row of dots marking progress through a fixed number of pages — the
/// current page's dot is wider and filled with the primary color.
class OnboardingDotsIndicator extends StatelessWidget {
  /// Creates the indicator for [count] pages, highlighting [currentIndex].
  const OnboardingDotsIndicator({
    required this.count,
    required this.currentIndex,
    super.key,
  });

  /// Total number of pages.
  final int count;

  /// Index of the page currently shown.
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: spacing.xxs / 2),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? colors.primary : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
