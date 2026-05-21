import 'package:video_player/video_player.dart';

/// Web stub for [fileVideoController].
///
/// Flutter web has no `dart:io` [File], so local file paths are treated as
/// network URLs (e.g. served via a dev server or object-storage URL).
VideoPlayerController fileVideoController(String path) =>
    VideoPlayerController.networkUrl(Uri.parse(path));
