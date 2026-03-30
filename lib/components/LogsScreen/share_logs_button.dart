import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';

import '../../services/noiseport_logs_helper.dart';

class ShareLogsButton extends StatelessWidget {
  const ShareLogsButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.adaptive.share),
      tooltip: AppLocalizations.of(context)!.shareLogs,
      onPressed: () async {
        final noiseportLogsHelper = GetIt.instance<NoiseportLogsHelper>();

        await noiseportLogsHelper.shareLogs();
      },
    );
  }
}
