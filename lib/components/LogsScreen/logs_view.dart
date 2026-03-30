import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'log_tile.dart';
import '../../services/noiseport_logs_helper.dart';

class LogsView extends StatelessWidget {
  const LogsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    NoiseportLogsHelper noiseportLogsHelper = GetIt.instance<NoiseportLogsHelper>();

    return Scrollbar(
      child: ListView.builder(
        itemCount: noiseportLogsHelper.logs.length,
        reverse: true,
        itemBuilder: (context, index) {
          return LogTile(
              logRecord: noiseportLogsHelper.logs.reversed.elementAt(index));
        },
      ),
    );
  }
}
