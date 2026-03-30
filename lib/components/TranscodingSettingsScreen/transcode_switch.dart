import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';
import 'package:hive/hive.dart';

import '../../services/noiseport_settings_helper.dart';
import '../../models/noiseport_models.dart';

class TranscodeSwitch extends StatelessWidget {
  const TranscodeSwitch({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<NoiseportSettings>>(
      valueListenable: NoiseportSettingsHelper.noiseportSettingsListener,
      builder: (context, box, child) {
        bool? shouldTranscode = box.get("NoiseportSettings")?.shouldTranscode;

        return SwitchListTile.adaptive(
          title: Text(AppLocalizations.of(context)!.enableTranscoding),
          subtitle:
              Text(AppLocalizations.of(context)!.enableTranscodingSubtitle),
          value: shouldTranscode ?? false,
          onChanged: shouldTranscode == null
              ? null
              : (value) {
                  NoiseportSettings noiseportSettingsTemp =
                      box.get("NoiseportSettings")!;
                  noiseportSettingsTemp.shouldTranscode = value;
                  box.put("NoiseportSettings", noiseportSettingsTemp);
                },
        );
      },
    );
  }
}
