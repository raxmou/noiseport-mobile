import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../services/noiseport_settings_helper.dart';
import '../../models/noiseport_models.dart';

class HideTabToggle extends StatelessWidget {
  const HideTabToggle({
    Key? key,
    required this.tabContentType,
  }) : super(key: key);

  final TabContentType tabContentType;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<NoiseportSettings>>(
      valueListenable: NoiseportSettingsHelper.noiseportSettingsListener,
      builder: (_, box, __) {
        return SwitchListTile.adaptive(
          title: Text(tabContentType.toLocalisedString(context)),
          // secondary: const Icon(Icons.drag_handle),
          // This should never be null, but it gets set to true if it is.
          value: NoiseportSettingsHelper.noiseportSettings.showTabs[tabContentType] ??
              true,
          onChanged: (value) =>
              NoiseportSettingsHelper.setShowTab(tabContentType, value),
        );
      },
    );
  }
}
