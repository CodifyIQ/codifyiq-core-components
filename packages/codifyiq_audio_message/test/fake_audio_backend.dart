import 'dart:async';

import 'package:codifyiq_audio_message/codifyiq_audio_message.dart';

/// An [AudioPlayerBackend] that records calls and lets tests drive its
/// streams, so no platform player is needed.
class FakeAudioBackend implements AudioPlayerBackend {
  final calls = <String>[];
  final sources = <AudioMessageSource>[];

  /// When set, the next [setSource] waits for it instead of loading at once.
  Completer<void>? pendingLoad;

  /// When set, [setSource] throws it.
  Object? loadError;

  /// When set, the next [seek] waits for it instead of landing at once.
  Completer<void>? pendingSeek;

  /// When set, [seek] throws it.
  Object? seekError;

  final _state = StreamController<AudioBackendState>.broadcast(sync: true);
  final _position = StreamController<Duration>.broadcast(sync: true);
  final _duration = StreamController<Duration?>.broadcast(sync: true);

  @override
  Stream<AudioBackendState> get stateStream => _state.stream;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<Duration?> get durationStream => _duration.stream;

  /// Emits a backend state.
  void emit(AudioBackendProcessingState state, {bool isPlaying = false}) =>
      _state.add(
        AudioBackendState(processingState: state, isPlaying: isPlaying),
      );

  /// Reports [error] on the state stream, as just_audio does for playback
  /// failures.
  void emitError(Object error) => _state.addError(error);

  /// Emits a duration and a position.
  void emitTimes(Duration duration, [Duration position = Duration.zero]) {
    _duration.add(duration);
    _position.add(position);
  }

  @override
  Future<void> setSource(AudioMessageSource source) async {
    calls.add('setSource');
    sources.add(source);
    final pending = pendingLoad;
    pendingLoad = null;
    if (pending != null) await pending.future;
    final error = loadError;
    if (error != null) throw error;
  }

  @override
  Future<void> play() async {
    calls.add('play');
    emit(AudioBackendProcessingState.ready, isPlaying: true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    emit(AudioBackendProcessingState.ready);
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek $position');
    final pending = pendingSeek;
    pendingSeek = null;
    if (pending != null) await pending.future;
    final error = seekError;
    if (error != null) throw error;
    _position.add(position);
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  void dispose() => calls.add('dispose');
}
