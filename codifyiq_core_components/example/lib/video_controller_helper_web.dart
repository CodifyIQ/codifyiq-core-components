import 'package:video_player/video_player.dart';

VideoPlayerController fileController(String path) =>
    VideoPlayerController.networkUrl(Uri.parse(path));
