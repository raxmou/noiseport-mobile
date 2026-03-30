import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';

import '../../services/noiseport_settings_helper.dart';

class SongShuffleItemCountEditor extends StatefulWidget {
  const SongShuffleItemCountEditor({Key? key}) : super(key: key);

  @override
  State<SongShuffleItemCountEditor> createState() =>
      _SongShuffleItemCountEditorState();
}

class _SongShuffleItemCountEditorState
    extends State<SongShuffleItemCountEditor> {
  final _controller = TextEditingController(
      text:
          NoiseportSettingsHelper.noiseportSettings.songShuffleItemCount.toString());

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.shuffleAllSongCount),
      subtitle: Text(AppLocalizations.of(context)!.shuffleAllSongCountSubtitle),
      trailing: SizedBox(
        width: 50 * MediaQuery.of(context).textScaleFactor,
        child: TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final valueInt = int.tryParse(value);

            if (valueInt != null) {
              NoiseportSettingsHelper.setSongShuffleItemCount(valueInt);
            }
          },
        ),
      ),
    );
  }
}
