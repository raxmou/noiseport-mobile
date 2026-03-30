import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';
import 'package:hive/hive.dart';

import '../../models/noiseport_models.dart';
import '../../services/noiseport_settings_helper.dart';

class ShowCoverAsPlayerBackgroundSelector extends StatelessWidget {
  const ShowCoverAsPlayerBackgroundSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<NoiseportSettings>>(
      valueListenable: NoiseportSettingsHelper.noiseportSettingsListener,
      builder: (_, box, __) {
        return SwitchListTile.adaptive(
          title:
              Text(AppLocalizations.of(context)!.showCoverAsPlayerBackground),
          subtitle: Text(AppLocalizations.of(context)!
              .showCoverAsPlayerBackgroundSubtitle),
          value:
              NoiseportSettingsHelper.noiseportSettings.showCoverAsPlayerBackground,
          onChanged: (value) =>
              NoiseportSettingsHelper.setShowCoverAsPlayerBackground(value),
        );
      },
    );
  }
}
