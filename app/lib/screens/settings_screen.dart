import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/extensions/snackbar_context.dart';
import 'package:gait_sense/repositories/user_preferences_repository.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Screen for editing persistent user preferences, currently only body height.
///
/// Height is required for the inverted-pendulum walking-speed estimate.
/// When height is absent the estimate is skipped and the summary screen shows
/// an explanatory message with a link back to this screen.
class SettingsScreen extends StatefulWidget {
  /// Creates the settings screen.
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHeight());
  }

  Future<void> _loadHeight() async {
    final prefs = context.read<UserPreferencesRepository>();
    final height = await prefs.getHeightCm();
    if (!mounted) return;
    if (height != null) {
      _heightController.text = height.round().toString();
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final heightCm = double.tryParse(_heightController.text.trim());
    if (heightCm == null) return;

    setState(() => _saving = true);
    final prefs = context.read<UserPreferencesRepository>();
    await prefs.setHeightCm(heightCm);
    if (!mounted) return;
    setState(() => _saving = false);
    context.showSnackBar('Postavke su spremljene.');
  }

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Postavke')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visina tijela',
                      style: context.textStyles.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Koristi se za procjenu duljine koraka i brzine hoda '
                      'inverted pendulum metodom (Zijlstra & Hof, 2003).',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Visina (cm)',
                        hintText: 'npr. 175',
                        border: OutlineInputBorder(),
                        suffixText: 'cm',
                      ),
                      validator: (value) {
                        final v = int.tryParse(value?.trim() ?? '');
                        if (v == null) return 'Unesite broj.';
                        if (v < 100 || v > 230) {
                          return 'Unesite visinu između 100 i 230 cm.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Spremi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
