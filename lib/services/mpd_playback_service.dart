import 'dart:async';
import 'dart:math';

import 'package:dart_mpd/dart_mpd.dart';
import 'package:logging/logging.dart';

/// Status data emitted by MpdPlaybackService's status stream.
class MpdPlaybackStatus {
  final bool isPlaying;
  final bool isPaused;
  final bool isStopped;
  final int? volume;
  final Duration elapsed;
  final Duration duration;
  final int? songIndex;
  final int? playlistLength;
  final String? error;

  MpdPlaybackStatus({
    this.isPlaying = false,
    this.isPaused = false,
    this.isStopped = true,
    this.volume,
    this.elapsed = Duration.zero,
    this.duration = Duration.zero,
    this.songIndex,
    this.playlistLength,
    this.error,
  });

  factory MpdPlaybackStatus.fromMpdStatus(MpdStatus status) {
    return MpdPlaybackStatus(
      isPlaying: status.state == MpdState.play,
      isPaused: status.state == MpdState.pause,
      isStopped: status.state == MpdState.stop,
      volume: status.volume,
      elapsed: Duration(
        milliseconds: ((status.elapsed ?? 0) * 1000).round(),
      ),
      duration: Duration(
        milliseconds: ((status.duration ?? 0) * 1000).round(),
      ),
      songIndex: status.song,
      playlistLength: status.playlistlength,
      error: status.error,
    );
  }

  factory MpdPlaybackStatus.disconnected() {
    return MpdPlaybackStatus(error: 'Not connected to MPD');
  }
}

/// Core MPD playback service using dart_mpd.
///
/// Manages connection, playback commands, queue, and status polling
/// for a remote MPD server.
class MpdPlaybackService {
  static final _log = Logger("MpdPlaybackService");

  MpdClient? _client;
  bool _connected = false;
  Timer? _statusPollTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  String? _lastHost;
  int? _lastPort;
  String? _lastPassword;

  /// Tracks the last known song index for optimized track navigation.
  int? _lastKnownSongIndex;

  /// Tracks the current queue length for boundary checks.
  int _queueLength = 0;

  final _statusController = StreamController<MpdPlaybackStatus>.broadcast();

  /// Stream of MPD playback status updates (polled every 1.5s).
  Stream<MpdPlaybackStatus> get statusStream => _statusController.stream;

  /// Whether the service is currently connected to an MPD server.
  bool get isConnected => _connected;

  /// The last known song index from status polling.
  int? get currentSongIndex => _lastKnownSongIndex;

  /// The current queue length.
  int get queueLength => _queueLength;

  /// Connect to an MPD server.
  Future<void> connect(String host, int port, {String? password}) async {
    await disconnect();

    _lastHost = host;
    _lastPort = port;
    _lastPassword = password;
    _reconnectAttempts = 0;

    try {
      _client = MpdClient(
        connectionDetails: MpdConnectionDetails(
          host: host,
          port: port,
        ),
      );

      // Send password command if provided
      if (password != null && password.isNotEmpty) {
        await _client!.connection.send('password "$password"');
      }

      // Verify connection by requesting status
      await _client!.status();

      _connected = true;
      _log.info('Connected to MPD at $host:$port');

      _startStatusPolling();
    } catch (e) {
      _connected = false;
      _client = null;
      _log.severe('Failed to connect to MPD at $host:$port', e);
      _statusController.add(MpdPlaybackStatus.disconnected());
      rethrow;
    }
  }

  /// Disconnect from the MPD server.
  Future<void> disconnect() async {
    _stopStatusPolling();
    _cancelReconnect();

    if (_client != null) {
      try {
        _client!.connection.close();
      } catch (e) {
        _log.warning('Error closing MPD connection', e);
      }
      _client = null;
    }

    _connected = false;
  }

  /// Test connection to an MPD server without persisting it.
  Future<bool> testConnection(String host, int port,
      {String? password}) async {
    MpdClient? testClient;
    try {
      testClient = MpdClient(
        connectionDetails: MpdConnectionDetails(
          host: host,
          port: port,
          timeout: const Duration(seconds: 5),
        ),
      );

      if (password != null && password.isNotEmpty) {
        await testClient.connection.send('password "$password"');
      }

      await testClient.status();
      _log.info('MPD test connection successful to $host:$port');
      return true;
    } catch (e) {
      _log.warning('MPD test connection failed to $host:$port', e);
      return false;
    } finally {
      try {
        testClient?.connection.close();
      } catch (_) {}
    }
  }

  // -- Playback commands --

  Future<void> play() async {
    _ensureConnected();
    try {
      await _client!.play(0);
    } catch (e) {
      _handleError('play', e);
    }
  }

  Future<void> pause() async {
    _ensureConnected();
    try {
      await _client!.pause(true);
    } catch (e) {
      _handleError('pause', e);
    }
  }

  Future<void> resume() async {
    _ensureConnected();
    try {
      await _client!.pause(false);
    } catch (e) {
      _handleError('resume', e);
    }
  }

  Future<void> stop() async {
    _ensureConnected();
    try {
      await _client!.stop();
    } catch (e) {
      _handleError('stop', e);
    }
  }

  Future<void> next() async {
    _ensureConnected();
    try {
      await _client!.next();
    } catch (e) {
      _handleError('next', e);
    }
  }

  Future<void> previous() async {
    _ensureConnected();
    try {
      await _client!.previous();
    } catch (e) {
      _handleError('previous', e);
    }
  }

  /// Skip to a specific queue index using optimized navigation.
  ///
  /// Uses `next` or `previous` for adjacent tracks (1 command),
  /// or `play <index>` for jumps (1 command vs N+2 for queue rebuild).
  Future<void> skipToIndex(int index) async {
    _ensureConnected();
    try {
      if (index < 0 || index >= _queueLength) {
        _log.warning('skipToIndex: index $index out of bounds (0-${_queueLength - 1})');
        return;
      }

      final currentIndex = _lastKnownSongIndex;
      if (currentIndex == null) {
        // No current index known, just play at the target index
        _log.info('skipToIndex: no current index, playing at $index');
        await _client!.play(index);
        return;
      }

      final diff = index - currentIndex;

      if (diff == 1) {
        // Adjacent forward: use next (more efficient, 1 command)
        _log.info('skipToIndex: adjacent forward ($currentIndex → $index), using next');
        await _client!.next();
      } else if (diff == -1) {
        // Adjacent backward: use previous (more efficient, 1 command)
        _log.info('skipToIndex: adjacent backward ($currentIndex → $index), using previous');
        await _client!.previous();
      } else {
        // Jump: use play <index> (1 command, still efficient)
        _log.info('skipToIndex: jump ($currentIndex → $index), using play');
        await _client!.play(index);
      }
    } catch (e) {
      _handleError('skipToIndex', e);
    }
  }

  /// Seek to [position] within the current song.
  Future<void> seek(Duration position) async {
    _ensureConnected();
    try {
      final seconds = position.inMilliseconds / 1000.0;
      await _client!.seekcur(seconds.toStringAsFixed(3));
    } catch (e) {
      _handleError('seek', e);
    }
  }

  /// Set volume (0-100).
  Future<void> setVolume(int volume) async {
    _ensureConnected();
    try {
      await _client!.setvol(volume.clamp(0, 100));
    } catch (e) {
      _handleError('setVolume', e);
    }
  }

  // -- Queue management --

  /// Clear the MPD queue and set a new queue from [uris], starting
  /// playback at [startIndex].
  Future<void> setQueue(List<Uri> uris, {int startIndex = 0}) async {
    _ensureConnected();
    try {
      // Verify connection is alive
      final preStatus = await _client!.status();
      _log.info('setQueue: pre-status state=${preStatus.state}, '
          'playlistLength=${preStatus.playlistlength}, '
          'error=${preStatus.error}');

      _log.info('setQueue: clearing queue');
      await _client!.clear();

      for (int i = 0; i < uris.length; i++) {
        final uriStr = uris[i].toString();
        _log.info('setQueue: adding [$i] $uriStr');
        try {
          await _client!.add(uriStr);
          _log.info('setQueue: add [$i] OK');
        } catch (addErr) {
          _log.severe('setQueue: add [$i] FAILED: $addErr');
          // Try alternative: use raw command with full URI
          // Some MPD versions need different handling for HTTP URLs
          rethrow;
        }
      }

      // Verify items were added
      final midStatus = await _client!.status();
      _log.info('setQueue: after adds, playlistLength=${midStatus.playlistlength}');

      // Track queue length after adding items
      _queueLength = uris.length;

      if (uris.isNotEmpty) {
        final playIdx = startIndex.clamp(0, uris.length - 1);
        _log.info('setQueue: playing from index $playIdx');
        await _client!.play(playIdx);
        _lastKnownSongIndex = playIdx;
        _log.info('setQueue: play command sent');

        // Brief delay then check if MPD is actually playing
        await Future.delayed(const Duration(milliseconds: 500));
        final postStatus = await _client!.status();
        _log.info('setQueue: post-play state=${postStatus.state}, '
            'song=${postStatus.song}, '
            'elapsed=${postStatus.elapsed}, '
            'duration=${postStatus.duration}, '
            'playlistLength=${postStatus.playlistlength}, '
            'error=${postStatus.error}');

        if (postStatus.state == MpdState.stop) {
          _log.warning('setQueue: MPD stopped immediately after play! '
              'Possible causes: URL not accessible from MPD server, '
              'unsupported format, or missing curl input plugin');
        }
      }
    } catch (e) {
      _log.severe('setQueue FAILED', e);
      _handleError('setQueue', e);
    }
  }

  /// Append [uris] to the end of the current MPD queue.
  Future<void> addToQueue(List<Uri> uris) async {
    _ensureConnected();
    try {
      for (final uri in uris) {
        await _client!.add(uri.toString());
      }
    } catch (e) {
      _handleError('addToQueue', e);
    }
  }

  /// Get the current MPD status.
  Future<MpdPlaybackStatus> getStatus() async {
    _ensureConnected();
    try {
      final status = await _client!.status();
      return MpdPlaybackStatus.fromMpdStatus(status);
    } catch (e) {
      _handleError('getStatus', e);
      return MpdPlaybackStatus.disconnected();
    }
  }

  /// Dispose of the service (call on app shutdown).
  void dispose() {
    disconnect();
    _statusController.close();
  }

  // -- Private helpers --

  void _ensureConnected() {
    if (!_connected || _client == null) {
      throw StateError('Not connected to MPD server');
    }
  }

  void _handleError(String command, dynamic error) {
    _log.severe('MPD command "$command" failed', error);

    // Check if it's a connection error that warrants reconnection
    if (error.toString().contains('Socket') ||
        error.toString().contains('Connection')) {
      _connected = false;
      _statusController.add(MpdPlaybackStatus.disconnected());
      _attemptReconnect();
    }
  }

  void _startStatusPolling() {
    _stopStatusPolling();
    _statusPollTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => _pollStatus(),
    );
  }

  void _stopStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
  }

  Future<void> _pollStatus() async {
    if (!_connected || _client == null) return;

    try {
      final status = await _client!.status();
      // Track current song index and queue length for optimized navigation
      _lastKnownSongIndex = status.song;
      _queueLength = status.playlistlength ?? 0;
      _statusController.add(MpdPlaybackStatus.fromMpdStatus(status));
    } catch (e) {
      _log.warning('Status poll failed', e);
      _connected = false;
      _statusController.add(MpdPlaybackStatus.disconnected());
      _attemptReconnect();
    }
  }

  void _attemptReconnect() {
    if (_reconnectTimer != null) return; // already trying
    if (_lastHost == null || _lastPort == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log.warning(
          'Max reconnect attempts ($_maxReconnectAttempts) reached, giving up');
      return;
    }

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s max
    final delaySeconds =
        min(pow(2, _reconnectAttempts).toInt(), 30);
    _reconnectAttempts++;

    _log.info(
        'Attempting MPD reconnect in ${delaySeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      _doReconnect();
    });
  }

  Future<void> _doReconnect() async {
    try {
      await connect(_lastHost!, _lastPort!, password: _lastPassword);
      _log.info('MPD reconnected successfully');
    } catch (e) {
      _log.warning('MPD reconnect attempt failed', e);
      if (_reconnectAttempts < _maxReconnectAttempts) {
        _attemptReconnect();
      }
    }
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
  }
}
