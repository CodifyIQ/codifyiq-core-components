import 'package:video_player/video_player.dart';

/// Web stub for [fileVideoController].
///
/// Flutter web has no `dart:io` [File], so this throws when invoked. Callers
/// should use `VideoSource.uri` or `VideoSource.asset` on the web target
/// instead.
VideoPlayerController fileVideoController(String path) {
  throw UnsupportedError(
    'VideoSource.file is not supported on Flutter web. '
    'Use VideoSource.uri or VideoSource.asset.',
  );
}
