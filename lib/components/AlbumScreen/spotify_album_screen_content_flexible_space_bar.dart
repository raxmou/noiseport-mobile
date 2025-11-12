import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:chopper/chopper.dart';
import 'package:network_info_plus/network_info_plus.dart'; // Add this import

import 'package:flutter/material.dart';
import 'package:finamp/l10n/app_localizations.dart';

import '../../models/jellyfin_models.dart';
import '../../services/finamp_settings_helper.dart';
import '../album_image.dart';
import 'item_info.dart';

class SpotifyAlbumScreenContentFlexibleSpaceBar extends StatelessWidget {
  const SpotifyAlbumScreenContentFlexibleSpaceBar({
    Key? key,
    required this.album,
    required this.items,
  }) : super(key: key);

  final BaseItemDto album;
  final List<BaseItemDto> items;

  @override
  Widget build(BuildContext context) {
    return FlexibleSpaceBar(
      background: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(
                      height: 125,
                      child: AlbumImage(item: album),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                    ),
                    Expanded(
                      flex: 2,
                      child: ItemInfo(
                        item: album,
                        itemSongs: items.length,
                      ),
                    )
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showDownloadDialog(context),
                        icon: const Icon(Icons.download),
                        label: Text(AppLocalizations.of(context)!.download),
                      ),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8)),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openInSpotify(context),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text("Open in Spotify"),
                      ),
                    ),
                  ]),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDownloadDialog(BuildContext context) async {
    try {
      final serverIp = FinampSettingsHelper.finampSettings.noiseportServerIp;
      if (serverIp.isEmpty) {
        _showErrorDialog(context,
            "Noiseport server IP not configured. Please set it in Settings > Noiseport Server.");
        return;
      }

      // Get Headscale IP (vpn_ip)
      final info = NetworkInfo();
      final vpnIp = await info.getWifiIP(); // Or use another method if needed

      // Extract album name and artists
      final albumName = album.name ?? "Unknown Album";
      final artistNames =
          album.albumArtists?.map((artist) => artist.name).join(', ') ??
              album.albumArtist ??
              "Unknown Artist";

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Downloading Album"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text("Sending \"$albumName\" by $artistNames to download..."),
              ],
            ),
          );
        },
      );

      // Create Chopper client for the download API
      final downloadClient = ChopperClient(
        baseUrl: Uri.parse('http://$serverIp:8000'),
        converter: JsonConverter(),
      );

      // Make the POST request, include vpn_ip
      final response = await downloadClient.post(
        Uri.parse('/api/v1/downloads/download'),
        body: {
          'album': albumName,
          'artist': artistNames,
          'vpn_ip': vpnIp ?? '', // Add vpn_ip here
        },
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (response.isSuccessful) {
        // Show success modal
        _showSuccessModal(context, albumName, artistNames);
      } else {
        // Show error message
        _showErrorDialog(
            context, "Failed to send album to download. Please try again.");
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      _showErrorDialog(context,
          "Network error. Please check your connection and try again.");
    }
  }

  void _showSuccessModal(
      BuildContext context, String albumName, String artistNames) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text("Download Started"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Album has been sent to download:",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                albumName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                "by $artistNames",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).disabledColor,
                    ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.error,
                color: Theme.of(context).colorScheme.error,
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text("Download Failed"),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _openInSpotify(BuildContext context) {
    // TODO: Implement opening in Spotify app or web
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Opening in Spotify..."),
      ),
    );
  }
}
