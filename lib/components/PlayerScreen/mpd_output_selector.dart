import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/noiseport_models.dart';
import '../../services/noiseport_settings_helper.dart';
import '../../services/jellyfin_stream_helper.dart';
import '../../services/mpd_playback_service.dart';
import '../../services/music_player_background_task.dart';

/// Spotify Connect-style banner that shows current playback output.
/// Displayed at the bottom of the player screen when MPD is enabled.
/// Tapping switches between local and MPD playback.
class MpdOutputSelector extends StatelessWidget {
  const MpdOutputSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<NoiseportSettings>>(
      valueListenable: NoiseportSettingsHelper.noiseportSettingsListener,
      builder: (context, box, _) {
        final settings = NoiseportSettingsHelper.noiseportSettings;

        if (!settings.mpdEnabled) {
          return const SizedBox.shrink();
        }

        final mpdService = GetIt.instance<MpdPlaybackService>();

        return StreamBuilder<MpdPlaybackStatus>(
          stream: mpdService.statusStream,
          builder: (context, snapshot) {
            final isMpd = settings.isMpdMode;
            final connected = mpdService.isConnected;

            return GestureDetector(
              onTap: () => _toggleOutput(context, settings, mpdService),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isMpd
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.15)
                      : Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMpd ? Icons.speaker_group : Icons.phone_android,
                      size: 16,
                      color: isMpd
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isMpd
                          ? (connected
                              ? 'Playing on MPD'
                              : 'MPD disconnected')
                          : 'Playing on this device',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isMpd
                                ? Theme.of(context).colorScheme.primary
                                : null,
                            fontWeight:
                                isMpd ? FontWeight.w600 : FontWeight.normal,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.swap_horiz,
                      size: 14,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleOutput(BuildContext context, NoiseportSettings settings,
      MpdPlaybackService mpdService) async {
    final newMode = !settings.isMpdMode;

    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();

    if (newMode) {
      // Switching to MPD mode — capture current queue and position first
      final currentQueue = audioHandler.queue.valueOrNull;
      final playbackState = audioHandler.playbackState.valueOrNull;
      final currentIndex = playbackState?.queueIndex ?? 0;

      // Try to connect first
      if (!mpdService.isConnected) {
        try {
          await mpdService.connect(
            settings.mpdHost,
            settings.mpdPort,
            password: settings.mpdPassword.isNotEmpty
                ? settings.mpdPassword
                : null,
          );
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to connect to MPD: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Fully stop and clear local player so no audio can play from phone
      await audioHandler.silenceLocalPlayer();

      // Transfer queue to MPD
      if (currentQueue != null && currentQueue.isNotEmpty) {
        final uris = <Uri>[];
        for (final item in currentQueue) {
          // Extract item ID from MediaItem extras
          final itemJson = item.extras?['itemJson'];
          if (itemJson != null && itemJson['Id'] != null) {
            uris.add(JellyfinStreamHelper.buildStreamUrl(itemJson['Id']));
          }
        }

        if (uris.isNotEmpty) {
          await mpdService.setQueue(uris, startIndex: currentIndex);
        }
      }
    } else {
      // Switching back to local mode — capture current position before stopping
      final currentIndex = mpdService.currentSongIndex ?? 0;
      final currentQueue = audioHandler.queue.valueOrNull;

      // Stop MPD playback and disconnect
      await mpdService.stop();
      await mpdService.disconnect();

      // Restore local player with current queue
      // This rebuilds the audio sources that were cleared by silenceLocalPlayer()
      if (currentQueue != null && currentQueue.isNotEmpty) {
        await audioHandler.restoreLocalPlayback(currentQueue, currentIndex);
      }
    }

    NoiseportSettingsHelper.setIsMpdMode(newMode);
  }
}
