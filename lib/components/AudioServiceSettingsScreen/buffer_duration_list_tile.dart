import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';

import '../../services/noiseport_settings_helper.dart';

class BufferDurationListTile extends StatefulWidget {
  const BufferDurationListTile({super.key});

  @override
  State<BufferDurationListTile> createState() => _BufferDurationListTileState();
}

class _BufferDurationListTileState extends State<BufferDurationListTile> {
  final _controller = TextEditingController(
      text:
          NoiseportSettingsHelper.noiseportSettings.bufferDurationSeconds.toString());

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.bufferDuration),
      subtitle: Text(AppLocalizations.of(context)!.bufferDurationSubtitle),
      trailing: SizedBox(
        width: 50 * MediaQuery.of(context).textScaleFactor,
        child: TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final valueInt = int.tryParse(value);

            if (valueInt != null && !valueInt.isNegative) {
              NoiseportSettingsHelper.setBufferDuration(
                  Duration(seconds: valueInt));
            }
          },
        ),
      ),
    );
  }
}
