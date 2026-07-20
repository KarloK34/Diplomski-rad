import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Circular avatar for [imageUrl], showing a progress spinner while it
/// loads and falling back to [icon] when there's no URL or it fails to load.
class UserAvatar extends StatelessWidget {
  /// Creates an avatar of the given [radius].
  const UserAvatar({
    required this.radius,
    this.imageUrl,
    this.icon = Icons.person,
    super.key,
  });

  /// Avatar circle radius.
  final double radius;

  /// Picture to load, e.g. a Google account's profile photo. Null shows
  /// [icon] directly instead of attempting a network load.
  final String? imageUrl;

  /// Icon shown when there's no [imageUrl] or it fails to load.
  final IconData icon;

  static const _fadeDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = imageUrl;
    if (url == null) return _fallback(colors);

    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedSwitcher(
            duration: _fadeDuration,
            child: frame == null
                ? _spinner(colors, key: const ValueKey('spinner'))
                : KeyedSubtree(key: const ValueKey('image'), child: child),
          );
        },
        errorBuilder: (context, error, stackTrace) => _fallback(colors),
      ),
    );
  }

  Widget _spinner(ColorScheme colors, {required Key key}) {
    return Container(
      key: key,
      width: radius * 2,
      height: radius * 2,
      color: colors.primaryContainer,
      alignment: Alignment.center,
      child: SizedBox(
        width: radius * 0.8,
        height: radius * 0.8,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _fallback(ColorScheme colors) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      child: Icon(icon, color: colors.onPrimaryContainer),
    );
  }
}
