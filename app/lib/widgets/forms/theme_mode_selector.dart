import 'package:flutter/material.dart';

/// A three-way segmented control for choosing the app's theme mode.
class ThemeModeSelector extends StatelessWidget {
  /// Creates the selector bound to [value], calling [onChanged] on selection.
  const ThemeModeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// The currently selected theme mode.
  final ThemeMode value;

  /// Called with the newly selected theme mode.
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto),
          label: Text('Sustav'),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode),
          label: Text('Svijetlo'),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode),
          label: Text('Tamno'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
