import 'dart:io';

import 'package:video_player/video_player.dart';

/// Returns a controller that plays a file on the device's file system.
///
/// Non-web implementation — uses a `dart:io` [File].
VideoPlayerController fileVideoController(String path) =>
    VideoPlayerController.file(File(path));
