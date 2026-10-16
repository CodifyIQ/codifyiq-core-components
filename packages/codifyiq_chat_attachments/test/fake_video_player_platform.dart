import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A [VideoPlayerPlatform] that plays nothing but records what it was asked
/// to do, so the widgets can be tested without a real player.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  /// Method names in call order, e.g. `play`, `pause`, `seekTo`.
  final List<String> calls = <String>[];

  /// The sources of every player created so far.
  final List<DataSource> dataSources = <DataSource>[];

  /// The volume most recently set on any player.
  double? volume;

  /// The position most recently sought to on any player.
  Duration? soughtTo;

  /// When `true`, the next players fail to load.
  bool failToLoad = false;

  /// Whether creating a player throws, as the real plugins do for an asset
  /// that isn't in the bundle.
  bool failToCreate = false;

  /// Length reported for every video.
  Duration duration = const Duration(seconds: 90);

  final Map<int, StreamController<VideoEvent>> _streams =
      <int, StreamController<VideoEvent>>{};
  int _nextPlayerId = 0;

  /// Sends [event] to the most recently created player.
  void emit(VideoEvent event) => _streams[_nextPlayerId - 1]!.add(event);

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) => createWithOptions(
    VideoCreationOptions(
      dataSource: dataSource,
      viewType: VideoViewType.textureView,
    ),
  );

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    if (failToCreate) {
      throw PlatformException(code: 'video_player', message: 'not found');
    }
    final stream = StreamController<VideoEvent>();
    _streams[_nextPlayerId] = stream;
    if (failToLoad) {
      stream.addError(PlatformException(code: 'VideoError', message: 'nope'));
    } else {
      stream.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          size: const Size(1280, 720),
          duration: duration,
        ),
      );
    }
    dataSources.add(options.dataSource);
    return _nextPlayerId++;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _streams[playerId]!.stream;

  // Like the HTML <video> view on web, the view joins the gesture arena for
  // every touch on it, and wins taps that nothing else claims.
  @override
  Widget buildView(int playerId) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {},
    child: const SizedBox.expand(),
  );

  @override
  Future<Duration> getPosition(int playerId) async => soughtTo ?? Duration.zero;

  @override
  Future<void> dispose(int playerId) async => calls.add('dispose');

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    calls.add('seekTo');
    soughtTo = position;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      calls.add('setLooping $looping');

  @override
  Future<void> setVolume(int playerId, double volume) async {
    calls.add('setVolume');
    this.volume = volume;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
