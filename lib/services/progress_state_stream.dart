import 'package:audio_service/audio_service.dart';
import 'package:get_it/get_it.dart';
import 'package:rxdart/rxdart.dart';

import 'noiseport_settings_helper.dart';
import 'mpd_playback_service.dart';
import 'music_player_background_task.dart';

class ProgressState {
  final MediaItem? mediaItem;
  final PlaybackState playbackState;
  final Duration position;

  ProgressState(this.mediaItem, this.playbackState, this.position);
}

/// Encapsulate all the different data we're interested in into a single
/// stream so we don't have to nest StreamBuilders.
Stream<ProgressState> get progressStateStream {
  final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  final mpdService = GetIt.instance<MpdPlaybackService>();

  // Stream that provides position from either MPD or local player
  final positionStream = Rx.combineLatest2<Duration, MpdPlaybackStatus?, Duration>(
    AudioService.position.startWith(audioHandler.playbackState.value.position),
    mpdService.statusStream.map<MpdPlaybackStatus?>((s) => s).startWith(null),
    (localPosition, mpdStatus) {
      final settings = NoiseportSettingsHelper.noiseportSettings;
      if (settings.mpdEnabled && settings.isMpdMode && mpdStatus != null) {
        // Use MPD's elapsed time when in MPD mode
        return mpdStatus.elapsed;
      }
      return localPosition;
    },
  );

  return Rx.combineLatest3<MediaItem?, PlaybackState, Duration, ProgressState>(
      audioHandler.mediaItem,
      audioHandler.playbackState,
      positionStream,
      (mediaItem, playbackState, position) =>
          ProgressState(mediaItem, playbackState, position));
}
