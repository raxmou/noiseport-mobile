import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';
import 'package:hive/hive.dart';

import '../../services/noiseport_settings_helper.dart';
import '../../models/noiseport_models.dart';

class BitrateSelector extends StatelessWidget {
  const BitrateSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text(AppLocalizations.of(context)!.bitrate),
          subtitle: Text(AppLocalizations.of(context)!.bitrateSubtitle),
        ),
        ValueListenableBuilder<Box<NoiseportSettings>>(
          valueListenable: NoiseportSettingsHelper.noiseportSettingsListener,
          builder: (context, box, child) {
            final noiseportSettings = box.get("NoiseportSettings")!;

            // We do all of this division/multiplication because Jellyfin wants us to specify bitrates in bits, not kilobits.
            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Slider(
                  min: 64,
                  max: 320,
                  value: noiseportSettings.transcodeBitrate / 1000,
                  divisions: 8,
                  label: "${noiseportSettings.transcodeBitrate ~/ 1000}kbps",
                  onChanged: (value) {
                    NoiseportSettingsHelper.setTranscodeBitrate(
                        (value * 1000).toInt());
                  },
                ),
                Text(
                  "${noiseportSettings.transcodeBitrate ~/ 1000}kbps",
                  style: Theme.of(context).textTheme.titleLarge,
                )
              ],
            );
          },
        ),
      ],
    );
  }
}
