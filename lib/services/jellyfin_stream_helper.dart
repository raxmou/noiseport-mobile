import 'package:get_it/get_it.dart';

import 'finamp_settings_helper.dart';
import 'finamp_user_helper.dart';

/// Shared utility for building Jellyfin stream URLs.
/// Used by both MusicPlayerBackgroundTask (local playback) and
/// MpdPlaybackService (remote MPD playback).
class JellyfinStreamHelper {
  /// Builds a direct-play HTTP URL for a Jellyfin item.
  ///
  /// When [transcode] is true, returns an HLS transcoding URL.
  /// When false (default), returns a direct file URL — suitable for MPD
  /// which handles its own decoding.
  static Uri buildStreamUrl(String itemId, {bool transcode = false}) {
    final finampUserHelper = GetIt.instance<FinampUserHelper>();
    final currentUser = finampUserHelper.currentUser!;

    final parsedBaseUrl = Uri.parse(currentUser.baseUrl);
    List<String> builtPath = List.from(parsedBaseUrl.pathSegments);

    Map<String, String> queryParameters =
        Map.from(parsedBaseUrl.queryParameters);

    queryParameters["ApiKey"] = currentUser.accessToken;

    if (transcode) {
      builtPath.addAll([
        "Audio",
        itemId,
        "main.m3u8",
      ]);

      queryParameters.addAll({
        "audioCodec": "aac",
        "audioSampleRate": "44100",
        "maxAudioBitDepth": "16",
        "audioBitRate":
            FinampSettingsHelper.finampSettings.transcodeBitrate.toString(),
      });
    } else {
      builtPath.addAll([
        "Items",
        itemId,
        "File",
      ]);
    }

    return Uri(
      host: parsedBaseUrl.host,
      port: parsedBaseUrl.port,
      scheme: parsedBaseUrl.scheme,
      userInfo: parsedBaseUrl.userInfo,
      pathSegments: builtPath,
      queryParameters: queryParameters,
    );
  }
}
