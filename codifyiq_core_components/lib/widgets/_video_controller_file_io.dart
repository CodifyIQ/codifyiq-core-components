import 'dart:io';

import 'package:video_player/video_player.dart';

/// Returns a [VideoPlayerController] backed by a local file.
///
/// Non-web implementation — uses [VideoPlayerController.file] with a
/// `dart:io` [File].
VideoPlayerController fileVideoController(String path) =>
    VideoPlayerController.file(File(path));
