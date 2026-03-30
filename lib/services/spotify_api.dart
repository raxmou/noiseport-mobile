import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:chopper/chopper.dart';

import '../models/spotify_models.dart';
import '../services/noiseport_settings_helper.dart';

class SpotifyApi {
  final _logger = Logger("SpotifyApi");
  final ChopperClient _client;

  SpotifyApi()
      : _client = ChopperClient(
          baseUrl: Uri.parse("https://api.spotify.com"),
          converter: JsonConverter(),
        );

  Future<SpotifySearchResponse?> searchAlbums(
    String query,
    String type,
    int limit,
    int offset,
  ) async {
    try {
      final token = await _getSpotifyToken();

      final response = await _client.get(
        Uri.parse("/v1/search"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        parameters: {
          "q": query,
          "type": type,
          "limit": limit.toString(),
          "offset": offset.toString(),
        },
      );

      if (response.isSuccessful && response.body != null) {
        return SpotifySearchResponse.fromJson(response.body);
      } else {
        _logger.warning(
            "Failed to search Spotify: ${response.statusCode} - ${response.error ?? response.body}");
        return null;
      }
    } catch (e) {
      _logger.severe("Error searching Spotify: $e");
      return null;
    }
  }

  Future<SpotifyAlbumTracksResponse?> getAlbumTracks(
    String albumId,
    int limit,
    int offset,
  ) async {
    try {
      final token = await _getSpotifyToken();

      final response = await _client.get(
        Uri.parse("/v1/albums/$albumId/tracks"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        parameters: {
          "limit": limit.toString(),
          "offset": offset.toString(),
        },
      );

      if (response.isSuccessful && response.body != null) {
        return SpotifyAlbumTracksResponse.fromJson(response.body);
      } else {
        _logger.warning("Failed to get album tracks: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      _logger.severe("Error getting album tracks: $e");
      return null;
    }
  }

  Future<String> _getSpotifyToken() async {
    try {
      final serverIp = NoiseportSettingsHelper.noiseportSettings.noiseportServerIp;

      if (serverIp.isEmpty) {
        throw Exception(
            "Noiseport server IP not configured. Please set it in Settings > Noiseport Server.");
      }

      final tokenClient = ChopperClient(
        baseUrl: Uri.parse("http://$serverIp:8010"),
        converter: JsonConverter(),
      );

      final response =
          await tokenClient.get(Uri.parse("/api/v1/config/spotify-token"));

      if (response.isSuccessful && response.body != null) {
        final tokenResponse = SpotifyTokenResponse.fromJson(response.body);
        return tokenResponse.access_token;
      } else {
        throw Exception(
            "Failed to fetch Spotify token: ${response.statusCode}");
      }
    } catch (e) {
      _logger.severe("Error fetching Spotify token: $e");
      rethrow;
    }
  }

  static SpotifyApi create() {
    return SpotifyApi();
  }
}
