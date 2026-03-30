import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';
import 'package:hive/hive.dart';

import '../../models/jellyfin_models.dart';
import '../../models/noiseport_models.dart';
import '../../services/noiseport_settings_helper.dart';

class SortOrderButton extends StatelessWidget {
  const SortOrderButton(this.tabType, {Key? key}) : super(key: key);

  final TabContentType tabType;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<NoiseportSettings>>(
      valueListenable: NoiseportSettingsHelper.noiseportSettingsListener,
      builder: (context, box, _) {
        final noiseportSettings = box.get("NoiseportSettings");

        return IconButton(
          tooltip: AppLocalizations.of(context)!.sortOrder,
          icon: noiseportSettings!.getSortOrder(tabType) == SortOrder.ascending
              ? const Icon(Icons.arrow_downward)
              : const Icon(Icons.arrow_upward),
          onPressed: () {
            if (noiseportSettings.getSortOrder(tabType) == SortOrder.ascending) {
              NoiseportSettingsHelper.setSortOrder(tabType,SortOrder.descending);
            } else {
              NoiseportSettingsHelper.setSortOrder(tabType, SortOrder.ascending);
            }
          },
        );
      },
    );
  }
}
