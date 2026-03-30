import 'package:noiseport/models/jellyfin_models.dart';
import 'package:noiseport/services/downloads_helper.dart';
import 'package:noiseport/services/sync_helper.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:noiseport/l10n/app_localizations.dart';

class SyncAlbumOrPlaylistButton extends StatefulWidget {
  const SyncAlbumOrPlaylistButton({
    Key? key,
    required this.parent,
    required this.items,
  }) : super(key: key);

  final BaseItemDto parent;
  final List<BaseItemDto> items;
  @override
  State<SyncAlbumOrPlaylistButton> createState() =>
      _SyncAlbumOrPlaylistButtonState();
}
class _SyncAlbumOrPlaylistButtonState
    extends State<SyncAlbumOrPlaylistButton> {
  final _syncLogger = Logger("SyncPlaylistButton");
  final _downloadHelper = GetIt.instance<DownloadsHelper>();
  bool isAlbumDownloaded = false;


  void syncAlbumOrPlaylist(BuildContext context) async {
    _syncLogger.info("Syncing playlist");

    var syncHelper = DownloadsSyncHelper(_syncLogger);
    syncHelper.sync(context, widget.parent, widget.items);
    setState(() {
      isAlbumDownloaded = _downloadHelper.isAlbumDownloaded(widget.parent.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    isAlbumDownloaded = _downloadHelper.isAlbumDownloaded(widget.parent.id);
    return IconButton(
        tooltip: isAlbumDownloaded
            ? AppLocalizations.of(context)!.sync
            : AppLocalizations.of(context)!.download,
        onPressed: () => syncAlbumOrPlaylist(context),
        icon:
        isAlbumDownloaded ?
        const Icon(Icons.sync) :
        const Icon(Icons.download));
  }
}
