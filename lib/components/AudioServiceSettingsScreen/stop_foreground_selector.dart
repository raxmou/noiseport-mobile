import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';
import 'package:hive/hive.dart';

import '../../services/noiseport_settings_helper.dart';
import '../../models/noiseport_models.dart';

class StopForegroundSelector extends StatelessWidget {
  const StopForegroundSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<NoiseportSettings>>(
      valueListenable: NoiseportSettingsHelper.noiseportSettingsListener,
      builder: (_, box, __) {
        return SwitchListTile.adaptive(
          title:
              Text(AppLocalizations.of(context)!.enterLowPriorityStateOnPause),
          subtitle: Text(AppLocalizations.of(context)!
              .enterLowPriorityStateOnPauseSubtitle),
          value:
              NoiseportSettingsHelper.noiseportSettings.androidStopForegroundOnPause,
          onChanged: (value) =>
              NoiseportSettingsHelper.setAndroidStopForegroundOnPause(value),
        );
      },
    );
  }
}
