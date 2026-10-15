import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

import 'audio_message_source.dart';
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

/// Plays audio messages, one at a time, for every player that shares it.
///
/// Own one per screen, like a chat controller, and pass it to each
/// `AudioMessageWidget` on that screen. Starting one message stops the one
/// that was playing, and a message keeps playing when its widget is disposed
/// — for example when a chat bubble scrolls out of view — until another
/// starts or the controller is disposed. A widget without a controller
/// creates its own.
///
/// It exposes the [currentId] being played, a simplified
/// [AudioPlaybackState], the current [position], total [duration], and
/// [progress] — all driven by the underlying backend streams. The source is
/// loaded on the first [play] of each message.
///
/// Pass a custom [backend] to substitute the default `just_audio` binding —
/// useful for testing or platforms where `just_audio` is unavailable.
///
/// This controller is **UI-only**: it does not manage downloads, caching,
/// or upload — consumers wire it to their own data layer.
class AudioMessageController extends ChangeNotifier {
  /// Creates an [AudioMessageController].
  ///
  /// [backend] defaults to [JustAudioPlayerBackend]. Supply a custom
  /// implementation to swap the audio engine or inject a test double.
  AudioMessageController({AudioPlayerBackend? backend})
    : _backend = backend ?? JustAudioPlayerBackend() {
    _listenToBackend();
  }

  final AudioPlayerBackend _backend;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Object? _currentId;
  AudioMessageSource? _source;
  // Counts loads, so a load that a newer one replaced is ignored.
  int _loads = 0;
  bool _loaded = false;
  bool _disposed = false;
  bool _completedOnce = false;
  AudioPlaybackState _state = AudioPlaybackState.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _rawError;

  /// The id of the message last passed to [play], whose playback the other
  /// getters describe, or `null` before anything has played.
  Object? get currentId => _currentId;

  /// The source last passed to [play], with [currentId].
  AudioMessageSource? get currentSource => _source;

  /// Raw platform error string when [state] is [AudioPlaybackState.error].
  /// Intended for logging only — may contain URLs or internal error codes.
  /// Display a fixed friendly message to users instead.
  String? get rawError => _rawError;

  /// Current playback state of [currentId].
  AudioPlaybackState get state => _state;

  /// Current playback position of [currentId].
  Duration get position => _position;

  /// Total duration of [currentId]. Zero until its source is loaded.
  Duration get duration => _duration;

  /// Playback progress in [0, 1]. Zero until the source is loaded.
  double get progress => _duration.inMilliseconds == 0
      ? 0.0
      : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

  /// Plays the message [id], loading [source] unless it is already the
  /// [currentId]. Any other message stops.
  ///
  /// No-ops while [id] is already loading or playing. Calling [play] after an
  /// error retries the load, and after a message completes it plays again
  /// from the start without re-fetching the source.
  Future<void> play(Object id, AudioMessageSource source) async {
    if (_disposed) return;
    final isCurrent = id == _currentId && source == _source;
    if (isCurrent &&
        (_state == AudioPlaybackState.loading ||
            _state == AudioPlaybackState.playing)) {
      return;
    }

    _rawError = null;

    if (!isCurrent || !_loaded) {
      final load = ++_loads;
      _currentId = id;
      _source = source;
      _loaded = false;
      _completedOnce = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _state = AudioPlaybackState.loading;
      notifyListeners();
      try {
        await _backend.setSource(source);
      } catch (e) {
        if (_disposed || load != _loads) return;
        _state = AudioPlaybackState.error;
        _rawError = e.toString();
        dev.log(_rawError!, name: 'AudioMessageController', level: 900);
        notifyListeners();
        return;
      }
      if (_disposed || load != _loads) return;
      _loaded = true;
    } else if (_completedOnce) {
      _completedOnce = false;
      await _backend.seek(Duration.zero);
    }

    if (_disposed) return;
    await _backend.play();
  }

  /// Pauses playback. No-op when not playing or disposed.
  ///
  /// While [currentId] is still loading, it cancels the load's playback, so
  /// the message doesn't start once its source arrives.
  Future<void> pause() async {
    if (_disposed) return;
    if (_state == AudioPlaybackState.loading && !_loaded) {
      _loads++;
      _state = AudioPlaybackState.idle;
      notifyListeners();
    }
    await _backend.pause();
  }

  /// Seeks [currentId] to [progress] ∈ [0, 1] of the total duration.
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
    // Players such as just_audio also report load and playback failures on
    // their streams; handled here, they show as an error rather than escaping
    // as uncaught errors.
    _subscriptions.add(
      _backend.stateStream.listen(_onBackendState, onError: _onBackendError),
    );
    _subscriptions.add(
      _backend.positionStream.listen((pos) {
        // Until the source has loaded, positions belong to the previous one.
        if (_disposed || !_loaded) return;
        _position = pos;
        notifyListeners();
      }, onError: _onBackendError),
    );
    _subscriptions.add(
      _backend.durationStream.listen((dur) {
        if (_disposed) return;
        if (dur != null) {
          _duration = dur;
          notifyListeners();
        }
      }, onError: _onBackendError),
    );
  }

  void _onBackendError(Object error) {
    if (_disposed || _state == AudioPlaybackState.error) return;
    _loaded = false;
    _state = AudioPlaybackState.error;
    _rawError = error.toString();
    dev.log(_rawError!, name: 'AudioMessageController', level: 900);
    notifyListeners();
  }

  void _onBackendState(AudioBackendState backendState) {
    // Until the source has loaded, states belong to the previous one.
    if (_disposed || !_loaded) return;
    switch (backendState.processingState) {
      case AudioBackendProcessingState.idle:
        // A failed load leaves the backend idle; keep showing the error.
        if (_state == AudioPlaybackState.error) return;
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
