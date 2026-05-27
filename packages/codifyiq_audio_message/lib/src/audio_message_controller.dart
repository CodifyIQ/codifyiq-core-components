import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

import 'audio_player_backend.dart';
import 'just_audio_player_backend.dart';

/// Playback states for [AudioMessageController].
enum AudioPlaybackState {
  /// No audio loaded; player is at rest.
  idle,

  /// Audio is being fetched or buffered.
  loading,

  /// Audio is actively playing.
  playing,

  /// Audio is loaded and paused.
  paused,

  /// A playback error occurred; see [AudioMessageController.rawError].
  error,
}

/// State container for a single audio message playback session.
///
/// Wraps an [AudioPlayerBackend] and exposes a simplified
/// [AudioPlaybackState] enum, current [position], total [duration], and
/// [progress] fraction — all driven by the underlying backend streams.
///
/// Typical lifecycle:
/// 1. Create a controller with the audio [url].
/// 2. Call [play] — the URL is fetched on the first call (state → loading).
/// 3. Call [pause] / [play] to toggle; [seek] to jump to a position.
/// 4. Dispose the controller when the owning widget is removed.
///
/// Pass a custom [backend] to substitute the default `just_audio` binding —
/// useful for testing or platforms where `just_audio` is unavailable.
///
/// This controller is **UI-only**: it does not manage downloads, caching,
/// or upload — consumers wire it to their own data layer.
class AudioMessageController extends ChangeNotifier {
  /// Creates a controller for the audio at [url].
  ///
  /// [backend] defaults to [JustAudioPlayerBackend]. Supply a custom
  /// implementation to swap the audio engine or inject a test double.
  AudioMessageController(this.url, {AudioPlayerBackend? backend})
    : _backend = backend ?? JustAudioPlayerBackend() {
    _listenToBackend();
  }

  /// The audio source URL (HTTP/HTTPS) or local file path.
  final String url;

  final AudioPlayerBackend _backend;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool _initialized = false;
  bool _disposed = false;
  bool _completedOnce = false;
  AudioPlaybackState _state = AudioPlaybackState.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _rawError;

  /// Raw platform error string when [state] is [AudioPlaybackState.error].
  /// Intended for logging only — may contain URLs or internal error codes.
  /// Display a fixed friendly message to users instead.
  String? get rawError => _rawError;

  /// Current playback state.
  AudioPlaybackState get state => _state;

  /// Current playback position.
  Duration get position => _position;

  /// Total duration of the audio. Zero until the URL is loaded.
  Duration get duration => _duration;

  /// Playback progress in [0, 1]. Zero until the URL is loaded.
  double get progress => _duration.inMilliseconds == 0
      ? 0.0
      : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

  /// Loads the URL (on first call) then starts playback.
  ///
  /// No-ops while [state] is [AudioPlaybackState.loading] or
  /// [AudioPlaybackState.playing]. Calling [play] from
  /// [AudioPlaybackState.error] clears the error and retries the load.
  /// After audio completes, [play] seeks to the start and replays without
  /// re-fetching the URL.
  Future<void> play() async {
    if (_disposed ||
        _state == AudioPlaybackState.loading ||
        _state == AudioPlaybackState.playing) {
      return;
    }

    _rawError = null;

    if (!_initialized) {
      _initialized = true;
      try {
        await _backend.setUrl(url);
      } catch (e) {
        _initialized = false;
        _state = AudioPlaybackState.error;
        _rawError = e.toString();
        dev.log(_rawError!, name: 'AudioMessageController', level: 900);
        notifyListeners();
        return;
      }
    } else if (_completedOnce) {
      _completedOnce = false;
      await _backend.seek(Duration.zero);
    }

    if (_disposed) return;
    await _backend.play();
  }

  /// Pauses playback. No-op when not playing or disposed.
  Future<void> pause() async {
    if (_disposed) return;
    await _backend.pause();
  }

  /// Seeks to [progress] ∈ [0, 1] of the total duration.
  ///
  /// No-op when disposed, duration unknown, or an error occurred.
  Future<void> seek(double progress) async {
    if (_disposed) return;
    if (_duration == Duration.zero || _state == AudioPlaybackState.error) {
      return;
    }
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * progress.clamp(0.0, 1.0))
          .round(),
    );
    await _backend.seek(target);
  }

  void _listenToBackend() {
    _subscriptions.add(_backend.stateStream.listen(_onBackendState));
    _subscriptions.add(
      _backend.positionStream.listen((pos) {
        if (_disposed) return;
        _position = pos;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _backend.durationStream.listen((dur) {
        if (_disposed) return;
        if (dur != null) {
          _duration = dur;
          notifyListeners();
        }
      }),
    );
  }

  void _onBackendState(AudioBackendState backendState) {
    if (_disposed) return;
    switch (backendState.processingState) {
      case AudioBackendProcessingState.idle:
        _state = AudioPlaybackState.idle;
      case AudioBackendProcessingState.loading:
      case AudioBackendProcessingState.buffering:
        _state = AudioPlaybackState.loading;
      case AudioBackendProcessingState.ready:
        _state = backendState.isPlaying
            ? AudioPlaybackState.playing
            : AudioPlaybackState.paused;
      case AudioBackendProcessingState.completed:
        _completedOnce = true;
        _state = AudioPlaybackState.idle;
        _position = Duration.zero;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _backend.dispose();
    super.dispose();
  }
}
