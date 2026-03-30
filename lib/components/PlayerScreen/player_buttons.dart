import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:noiseport/l10n/app_localizations.dart';
import 'package:rxdart/rxdart.dart';

import '../../services/noiseport_settings_helper.dart';
import '../../services/mpd_playback_service.dart';
import '../../services/music_player_background_task.dart';

/// Combined playback state that works for both local and MPD playback
class CombinedPlaybackState {
  final PlaybackState? localState;
  final MpdPlaybackStatus? mpdStatus;
  final bool isMpdMode;

  CombinedPlaybackState(this.localState, this.mpdStatus, this.isMpdMode);

  bool get isPlaying {
    if (isMpdMode && mpdStatus != null) {
      return mpdStatus!.isPlaying;
    }
    return localState?.playing ?? false;
  }

  bool get hasState => localState != null || (isMpdMode && mpdStatus != null);

  // Delegate other properties to local state (shuffle, repeat modes are local-only for now)
  AudioServiceShuffleMode get shuffleMode =>
      localState?.shuffleMode ?? AudioServiceShuffleMode.none;
  AudioServiceRepeatMode get repeatMode =>
      localState?.repeatMode ?? AudioServiceRepeatMode.none;
}

class PlayerButtons extends StatelessWidget {
  const PlayerButtons({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
    final mpdService = GetIt.instance<MpdPlaybackService>();

    // Combine local playback state with MPD status
    final combinedStream = Rx.combineLatest2<PlaybackState, MpdPlaybackStatus?, CombinedPlaybackState>(
      audioHandler.playbackState,
      mpdService.statusStream.map<MpdPlaybackStatus?>((s) => s).startWith(null),
      (localState, mpdStatus) {
        final settings = NoiseportSettingsHelper.noiseportSettings;
        return CombinedPlaybackState(
          localState,
          mpdStatus,
          settings.mpdEnabled && settings.isMpdMode,
        );
      },
    );

    return StreamBuilder<CombinedPlaybackState>(
      stream: combinedStream,
      builder: (context, snapshot) {
        final CombinedPlaybackState? combinedState = snapshot.data;
        return Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          textDirection: TextDirection.ltr,
          children: [
            IconButton(
              tooltip: combinedState?.shuffleMode == AudioServiceShuffleMode.all
                  ? AppLocalizations.of(context)!.playbackOrderShuffledTooltip
                  : AppLocalizations.of(context)!.playbackOrderLinearTooltip,
              icon: _getShufflingIcon(
                combinedState?.shuffleMode ?? AudioServiceShuffleMode.none,
                Theme.of(context).colorScheme.secondary,
              ),
              onPressed: combinedState?.hasState == true
                  ? () async {
                      if (combinedState!.shuffleMode ==
                          AudioServiceShuffleMode.all) {
                        await audioHandler
                            .setShuffleMode(AudioServiceShuffleMode.none);
                      } else {
                        await audioHandler
                            .setShuffleMode(AudioServiceShuffleMode.all);
                      }
                    }
                  : null,
              iconSize: 20,
            ),
            IconButton(
              tooltip: AppLocalizations.of(context)!.skipToPrevious,
              icon: const Icon(Icons.skip_previous),
              onPressed: combinedState?.hasState == true
                  ? () async => await audioHandler.skipToPrevious()
                  : null,
              iconSize: 36,
            ),
            SizedBox(
              height: 56,
              width: 56,
              child: FloatingActionButton(
                tooltip: AppLocalizations.of(context)!.togglePlayback,
                // We set a heroTag because otherwise the play button on AlbumScreenContent will do hero widget stuff
                heroTag: "PlayerScreenFAB",
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                splashColor:
                    Theme.of(context).colorScheme.onPrimary.withOpacity(0.24),
                onPressed: combinedState?.hasState == true
                    ? () async {
                        if (combinedState!.isPlaying) {
                          await audioHandler.pause();
                        } else {
                          await audioHandler.play();
                        }
                      }
                    : null,
                child: Icon(
                  combinedState == null || combinedState.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  size: 36,
                ),
              ),
            ),
            IconButton(
                tooltip: AppLocalizations.of(context)!.skipToNext,
                icon: const Icon(Icons.skip_next),
                onPressed: combinedState?.hasState == true
                    ? () async => audioHandler.skipToNext()
                    : null,
                iconSize: 36),
            IconButton(
              tooltip: combinedState?.repeatMode == AudioServiceRepeatMode.all
                  ? AppLocalizations.of(context)!.loopModeAllTooltip
                  : combinedState?.repeatMode == AudioServiceRepeatMode.one
                      ? AppLocalizations.of(context)!.loopModeOneTooltip
                      : AppLocalizations.of(context)!.loopModeNoneTooltip,
              icon: _getRepeatingIcon(
                combinedState?.repeatMode ?? AudioServiceRepeatMode.none,
                Theme.of(context).colorScheme.secondary,
              ),
              onPressed: combinedState?.hasState == true
                  ? () async {
                      // Cyles from none -> all -> one
                      if (combinedState!.repeatMode ==
                          AudioServiceRepeatMode.none) {
                        await audioHandler
                            .setRepeatMode(AudioServiceRepeatMode.all);
                      } else if (combinedState.repeatMode ==
                          AudioServiceRepeatMode.all) {
                        await audioHandler
                            .setRepeatMode(AudioServiceRepeatMode.one);
                      } else {
                        await audioHandler
                            .setRepeatMode(AudioServiceRepeatMode.none);
                      }
                    }
                  : null,
              iconSize: 20,
            ),
          ],
        );
      },
    );
  }

  Widget _getRepeatingIcon(
      AudioServiceRepeatMode repeatMode, Color iconColour) {
    if (repeatMode == AudioServiceRepeatMode.all) {
      return Icon(Icons.repeat, color: iconColour);
    } else if (repeatMode == AudioServiceRepeatMode.one) {
      return Icon(Icons.repeat_one, color: iconColour);
    } else {
      return const Icon(Icons.repeat);
    }
  }

  Icon _getShufflingIcon(
      AudioServiceShuffleMode shuffleMode, Color iconColour) {
    if (shuffleMode == AudioServiceShuffleMode.all) {
      return Icon(Icons.shuffle, color: iconColour);
    } else {
      return const Icon(Icons.shuffle);
    }
  }
}
