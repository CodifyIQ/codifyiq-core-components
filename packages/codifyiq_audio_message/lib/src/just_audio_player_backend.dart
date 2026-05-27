import 'package:just_audio/just_audio.dart';

import 'audio_player_backend.dart';

/// [AudioPlayerBackend] implementation backed by [just_audio]'s [AudioPlayer].
///
/// This is the default backend used by [AudioMessageController] when no
/// custom [AudioPlayerBackend] is supplied.
class JustAudioPlayerBackend implements AudioPlayerBackend {
  final AudioPlayer _player = AudioPlayer();

  @override
  Stream<AudioBackendState> get stateStream {
    AudioBackendState? last;
    return _player.playerStateStream
        .map(
          (s) => AudioBackendState(
            processingState: _toProcessingState(s.processingState),
            isPlaying: s.playing,
          ),
        )
        .where((s) {
          if (s == last) return false;
          last = s;
          return true;
        });
  }

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Future<void> setUrl(String url) async {
    await _player.setUrl(url);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  void dispose() => _player.dispose();

  static AudioBackendProcessingState _toProcessingState(
    ProcessingState state,
  ) => switch (state) {
    ProcessingState.idle => AudioBackendProcessingState.idle,
    ProcessingState.loading => AudioBackendProcessingState.loading,
    ProcessingState.buffering => AudioBackendProcessingState.buffering,
    ProcessingState.ready => AudioBackendProcessingState.ready,
    ProcessingState.completed => AudioBackendProcessingState.completed,
  };
}
