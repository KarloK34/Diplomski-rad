import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gait_sense/models/har_model_info.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/activity_labels.dart';
import 'package:gait_sense/widgets/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Shows app version, model info, and the open-source licenses page.
class AboutScreen extends StatefulWidget {
  /// Creates the about screen.
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPackageInfo());
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _packageInfo = info);
  }

  @override
  Widget build(BuildContext context) {
    final info = _packageInfo;
    final classLabels = (harModelInfo['class_labels'] as List<String>)
        .map(activityLabelHr)
        .join(', ');
    return InfoScreenScaffold(
      title: 'O aplikaciji',
      children: [
        InfoSection(
          title: 'Gait Sense',
          body: info == null
              ? '...'
              : 'Verzija ${info.version} (build ${info.buildNumber})',
        ),
        Text(
          'Analiza hoda i prepoznavanje aktivnosti na temelju IMU '
          'senzora pametnog telefona.',
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        InfoSection(title: 'Prepoznate aktivnosti', body: classLabels),
      ],
    );
  }
}
