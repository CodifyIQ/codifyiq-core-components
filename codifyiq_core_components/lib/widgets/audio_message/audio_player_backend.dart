/// Processing states emitted by [AudioPlayerBackend.stateStream].
enum AudioBackendProcessingState {
  /// Player is idle — no source loaded.
  idle,

  /// Source is being fetched.
  loading,

  /// Source is loaded but buffering.
  buffering,

  /// Source is ready for playback.
  ready,

  /// Playback has reached the end of the source.
  completed,
}

/// Snapshot of backend player state emitted by [AudioPlayerBackend.stateStream].
class AudioBackendState {
  /// Creates an [AudioBackendState].
  const AudioBackendState({
    required this.processingState,
    required this.isPlaying,
  });

  /// Current processing state of the underlying player.
  final AudioBackendProcessingState processingState;

  /// Whether the player is actively playing audio.
  final bool isPlaying;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioBackendState &&
          processingState == other.processingState &&
          isPlaying == other.isPlaying;

  @override
  int get hashCode => Object.hash(processingState, isPlaying);
}

/// Pluggable audio player interface consumed by [AudioMessageController].
///
/// Implement this to swap the default `just_audio` binding for a different
/// engine, a platform-specific player, or a test double.
///
/// The default implementation is [JustAudioPlayerBackend].
abstract interface class AudioPlayerBackend {
  /// Stream of player state snapshots.
  Stream<AudioBackendState> get stateStream;

  /// Stream of current playback position.
  Stream<Duration> get positionStream;

  /// Stream of total audio duration. Emits [null] when unknown.
  Stream<Duration?> get durationStream;

  /// Loads the audio source at [url].
  Future<void> setUrl(String url);

  /// Starts or resumes playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Seeks to [position].
  Future<void> seek(Duration position);

  /// Stops playback and releases the current source.
  Future<void> stop();

  /// Releases all resources held by this backend.
  void dispose();
}
