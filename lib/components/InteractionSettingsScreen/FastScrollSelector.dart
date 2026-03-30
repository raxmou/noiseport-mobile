import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';
import 'package:hive/hive.dart';

import '../../models/noiseport_models.dart';
import '../../services/noiseport_settings_helper.dart';

class FastScrollSelector extends StatelessWidget {
  const FastScrollSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<NoiseportSettings>>(
      valueListenable: NoiseportSettingsHelper.noiseportSettingsListener,
      builder: (_, box, __) {
        return SwitchListTile.adaptive(
          title: Text(AppLocalizations.of(context)!.showFastScroller),
          value: NoiseportSettingsHelper.noiseportSettings.showFastScroller,
          onChanged: (value) => NoiseportSettingsHelper.setShowFastScroller(value),
        );
      },
    );
  }
}