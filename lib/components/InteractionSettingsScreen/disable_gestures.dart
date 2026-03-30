import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';
import 'package:hive/hive.dart';

import '../../models/noiseport_models.dart';
import '../../services/noiseport_settings_helper.dart';

class DisableGestureSelector extends StatelessWidget {
  const DisableGestureSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<NoiseportSettings>>(
      valueListenable: NoiseportSettingsHelper.noiseportSettingsListener,
      builder: (_, box, __) {
        return SwitchListTile.adaptive(
          title: Text(AppLocalizations.of(context)!.disableGesture),
          subtitle: Text(AppLocalizations.of(context)!.disableGestureSubtitle),
          value: NoiseportSettingsHelper.noiseportSettings.disableGesture,
          onChanged: (value) => NoiseportSettingsHelper.setDisableGesture(value),
        );
      },
    );
  }
}
