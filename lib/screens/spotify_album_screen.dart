import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

import '../models/jellyfin_models.dart';
import '../models/noiseport_models.dart';
import '../services/noiseport_settings_helper.dart';
import '../services/spotify_api_helper.dart';
import '../components/now_playing_bar.dart';
import '../components/AlbumScreen/spotify_album_screen_content.dart';

class SpotifyAlbumScreen extends StatefulWidget {
  const SpotifyAlbumScreen({
    Key? key,
    this.parent,
  }) : super(key: key);

  static const routeName = "/music/spotify-album";

  /// The album to show. Can also be provided as an argument in a named route
  final BaseItemDto? parent;

  @override
  State<SpotifyAlbumScreen> createState() => _SpotifyAlbumScreenState();
}

class _SpotifyAlbumScreenState extends State<SpotifyAlbumScreen> {
  Future<List<BaseItemDto>?>? albumTracksContentFuture;
  SpotifyApiHelper spotifyApiHelper = SpotifyApiHelper();

  @override
  Widget build(BuildContext context) {
    final BaseItemDto parent = widget.parent ??
        ModalRoute.of(context)!.settings.arguments as BaseItemDto;

    return Scaffold(
      body: ValueListenableBuilder<Box<NoiseportSettings>>(
        valueListenable: NoiseportSettingsHelper.noiseportSettingsListener,
        builder: (context, box, widget) {
          bool isOffline = box.get("NoiseportSettings")?.isOffline ?? false;

          if (isOffline) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 64,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const Padding(padding: EdgeInsets.all(8.0)),
                  const Text("Spotify albums require internet connection")
                ],
              ),
            );
          }

          if (parent.id == null || parent.id!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error,
                    size: 64,
                    color: Colors.red.withOpacity(0.5),
                  ),
                  const Padding(padding: EdgeInsets.all(8.0)),
                  const Text("Invalid album ID")
                ],
              ),
            );
          }

          albumTracksContentFuture ??= spotifyApiHelper.getAlbumTracks(
            albumId: parent.id!,
          );

          return FutureBuilder<List<BaseItemDto>?>(
            future: albumTracksContentFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return SpotifyAlbumScreenContent(
                  parent: parent,
                  children: snapshot.data!,
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error,
                        size: 64,
                        color: Colors.red,
                      ),
                      const Padding(padding: EdgeInsets.all(8.0)),
                      Text(
                        "Error loading album: ${snapshot.error}",
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              } else {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
            },
          );
        },
      ),
      bottomNavigationBar: const NowPlayingBar(),
    );
  }
}