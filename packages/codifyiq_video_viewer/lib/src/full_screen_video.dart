import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import 'video_player_view.dart';

/// The page a `VideoViewerWidget` opens to show its video full screen.
///
/// It plays the same loaded video, so playback carries on where it was. On
/// phones and tablets it hides the status and navigation bars, and turns a
/// wide video to landscape; both are put back when the page closes. On web it
/// fills the page.
class FullScreenVideo extends StatefulWidget {
  /// Creates a full-screen page for the video that [controller] has loaded.
  const FullScreenVideo({
    super.key,
    required this.controller,
    required this.onToggleMute,
    this.onExit,
  });

  /// The loaded video.
  final VideoPlayerController controller;

  /// Mutes or unmutes the video.
  final VoidCallback onToggleMute;

  /// Called as the page closes, after the system bars and orientation are
  /// put back.
  final VoidCallback? onExit;

  @override
  State<FullScreenVideo> createState() => _FullScreenVideoState();
}

class _FullScreenVideoState extends State<FullScreenVideo> {
  bool _forcedLandscape = false;

  @override
  void initState() {
    super.initState();
    // Browsers only allow these from their own full-screen mode.
    if (kIsWeb) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (widget.controller.value.aspectRatio > 1) {
      _forcedLandscape = true;
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // An empty list hands orientation back to the app's own settings.
      if (_forcedLandscape) SystemChrome.setPreferredOrientations(const []);
    }
    widget.onExit?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: VideoPlayerView(
          controller: widget.controller,
          onToggleMute: widget.onToggleMute,
          isFullScreen: true,
          onToggleFullScreen: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
