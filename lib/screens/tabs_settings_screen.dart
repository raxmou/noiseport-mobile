import 'package:noiseport/services/noiseport_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';

import '../components/TabsSettingsScreen/hide_tab_toggle.dart';

class TabsSettingsScreen extends StatefulWidget {
  const TabsSettingsScreen({Key? key}) : super(key: key);

  static const routeName = "/settings/tabs";

  @override
  State<TabsSettingsScreen> createState() => _TabsSettingsScreenState();
}

class _TabsSettingsScreenState extends State<TabsSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.tabs),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                NoiseportSettingsHelper.resetTabs();
              });
            },
            icon: const Icon(Icons.refresh),
            tooltip: AppLocalizations.of(context)!.resetTabs,
          )
        ],
      ),
      body: Scrollbar(
        child: ReorderableListView.builder(
          // buildDefaultDragHandles: false,
          itemCount: NoiseportSettingsHelper.noiseportSettings.tabOrder.length,
          itemBuilder: (context, index) {
            return HideTabToggle(
              tabContentType:
                  NoiseportSettingsHelper.noiseportSettings.tabOrder[index],
              key:
                  ValueKey(NoiseportSettingsHelper.noiseportSettings.tabOrder[index]),
            );
          },
          onReorder: (oldIndex, newIndex) {
            // It's a bit of a hack to call setState with no actual widget
            // state, but it saves us from using listeners
            setState(() {
              // For some weird reason newIndex is one above what it should be
              // when oldIndex is lower. This if statement is in Flutter's
              // ReorderableListView documentation.
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }

              final oldValue =
                  NoiseportSettingsHelper.noiseportSettings.tabOrder[oldIndex];
              final newValue =
                  NoiseportSettingsHelper.noiseportSettings.tabOrder[newIndex];

              NoiseportSettingsHelper.setTabOrder(oldIndex, newValue);
              NoiseportSettingsHelper.setTabOrder(newIndex, oldValue);
            });
          },
        ),
      ),
    );
  }
}
