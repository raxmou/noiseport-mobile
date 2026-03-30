import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';

import '../../models/jellyfin_models.dart';
import '../favourite_button.dart';
import 'spotify_album_screen_content_flexible_space_bar.dart';
import 'spotify_track_list_tile.dart';

typedef BaseItemDtoCallback = void Function(BaseItemDto item);

class SpotifyAlbumScreenContent extends StatefulWidget {
  const SpotifyAlbumScreenContent({
    Key? key,
    required this.parent,
    required this.children,
  }) : super(key: key);

  final BaseItemDto parent;
  final List<BaseItemDto> children;

  @override
  State<SpotifyAlbumScreenContent> createState() => _SpotifyAlbumScreenContentState();
}

class _SpotifyAlbumScreenContentState extends State<SpotifyAlbumScreenContent> {
  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(widget.parent.name ??
                AppLocalizations.of(context)!.unknownName),
            // 125 + 64 is the total height of the widget we use as a
            // FlexibleSpaceBar. We add the toolbar height since the widget
            // should appear below the appbar.
            // TODO: This height is affected by platform density.
            expandedHeight: kToolbarHeight + 125 + 64,
            pinned: true,
            flexibleSpace: SpotifyAlbumScreenContentFlexibleSpaceBar(
              album: widget.parent,
              items: widget.children,
            ),
            actions: [
              // Remove favorite button and download button for Spotify albums
              // Could add "Open in Spotify" button here if needed
            ],
          ),
          // Simple track list without disc logic for Spotify albums
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                return SpotifyTrackListTile(
                  item: widget.children[index],
                  album: widget.parent,
                  onTap: () {
                    _showTrackInfo(context, widget.children[index]);
                  },
                );
              },
              childCount: widget.children.length,
            ),
          ),
        ],
      ),
    );
  }

  void _showTrackInfo(BuildContext context, BaseItemDto track) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(track.name ?? "Track"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (track.artists?.isNotEmpty == true)
                Text("Artist: ${track.artists!.join(', ')}"),
              if (track.runTimeTicks != null)
                Text("Duration: ${_formatDuration(track.runTimeTicks! ~/ 10000)}"),
              const SizedBox(height: 16),
              const Text("This is a Spotify track. Full playback is not available in this app."),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
            if (track.externalUrls?.isNotEmpty == true)
              TextButton(
                onPressed: () {
                  // TODO: Open Spotify URL
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Opening in Spotify...")),
                  );
                },
                child: const Text("Open in Spotify"),
              ),
          ],
        );
      },
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}