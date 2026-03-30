import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';
import 'package:hive/hive.dart';

import '../../models/noiseport_models.dart';
import '../../services/noiseport_settings_helper.dart';

class HideSongArtistsIfSameAsAlbumArtistsSelector extends StatelessWidget {
  const HideSongArtistsIfSameAsAlbumArtistsSelector({Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<NoiseportSettings>>(
      valueListenable: NoiseportSettingsHelper.noiseportSettingsListener,
      builder: (_, box, __) {
        return SwitchListTile.adaptive(
          title: Text(AppLocalizations.of(context)!
              .hideSongArtistsIfSameAsAlbumArtists),
          subtitle: Text(AppLocalizations.of(context)!
              .hideSongArtistsIfSameAsAlbumArtistsSubtitle),
          value: NoiseportSettingsHelper
              .noiseportSettings.hideSongArtistsIfSameAsAlbumArtists,
          onChanged: (value) =>
              NoiseportSettingsHelper.setHideSongArtistsIfSameAsAlbumArtists(
                  value),
        );
      },
    );
  }
}
