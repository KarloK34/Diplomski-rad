import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gait_sense/theme/app_radii.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// FAB-styled control that only fires [onConfirmed] after being held for
/// [holdDuration], so a stray tap (through a pocket, say) can't trigger it.
/// A filling ring tracks the hold; releasing early resets it, and a haptic
/// tick confirms the hold went through.
class HoldToConfirmFab extends StatefulWidget {
  /// Creates the control.
  const HoldToConfirmFab({
    required this.icon,
    required this.label,
    required this.onConfirmed,
    this.holdDuration = const Duration(milliseconds: 1200),
    super.key,
  });

  /// Icon shown at rest and, as an outline, inside the filling ring.
  final IconData icon;

  /// Label shown beside the icon.
  final String label;

  /// Called once the hold completes.
  final VoidCallback onConfirmed;

  /// How long the press must be held before [onConfirmed] fires.
  final Duration holdDuration;

  @override
  State<HoldToConfirmFab> createState() => _HoldToConfirmFabState();
}

class _HoldToConfirmFabState extends State<HoldToConfirmFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  )..addStatusListener(_onStatusChanged);

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    unawaited(HapticFeedback.mediumImpact());
    widget.onConfirmed();
    _controller.reset();
  }

  void _releaseEarly() {
    if (_controller.status != AnimationStatus.completed) {
      unawaited(_controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = colors.onPrimaryContainer;
    return GestureDetector(
      onLongPressStart: (_) => unawaited(_controller.forward()),
      onLongPressEnd: (_) => _releaseEarly(),
      onLongPressCancel: _releaseEarly,
      child: Material(
        color: colors.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        elevation: 6,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    // Only the progress ring depends on the animation, so it
                    // alone is rebuilt per tick via AnimatedBuilder's
                    // `builder`; the icon is passed through as `child`
                    // instead of being reconstructed on every tick too.
                    children: [
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => _controller.value > 0
                            ? CircularProgressIndicator(
                                value: _controller.value,
                                strokeWidth: 3.5,
                                color: foreground,
                                backgroundColor: foreground.withValues(
                                  alpha: 0.25,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Icon(widget.icon, size: 24, color: foreground),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: context.textStyles.labelLarge?.copyWith(
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
