import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '_video_file_io.dart'
    if (dart.library.js_interop) '_video_file_web.dart'
    as file_loader;
import 'full_screen_video.dart';
import 'video_player_view.dart';
import 'video_source.dart';

/// A video player with play/pause, a scrubber, elapsed and total time, a
/// mute button and a full-screen button.
///
/// Backed by the `video_player` plugin. Plays a video from any [VideoSource]
/// — a network [Uri], a local file path, or a bundled asset — letterboxed on
/// a black canvas inside whatever space it is given.
///
/// ```dart
/// AspectRatio(
///   aspectRatio: 16 / 9,
///   child: VideoViewerWidget(
///     source: VideoSource.uri(Uri.parse('https://example.com/clip.mp4')),
///   ),
/// )
/// ```
///
/// ## Controls
///
/// The controls sit over the video. Tapping the video shows or hides them,
/// and they hide themselves a few seconds after playback starts, or as soon
/// as something else on screen is tapped. They stay
/// visible while the video is paused or has finished; pressing play on a
/// finished video starts it again from the beginning.
///
/// On phones and tablets, double-tapping the left or right half of the video
/// jumps back or forward ten seconds. On macOS, Windows and Linux, including
/// in desktop browsers, a volume slider sits next to the mute button; phones
/// and tablets have hardware volume buttons, so there they get the mute
/// button alone.
///
/// The screen is kept awake while the video plays.
///
/// ## Full screen
///
/// The full-screen button opens the same video, still playing from where it
/// was, on a page of its own; closing it brings the video back inline. On
/// phones and tablets that page hides the status and navigation bars and
/// turns a wide video to landscape. When it closes, the bars come back in
/// edge-to-edge mode and orientation goes back to what the app declares in
/// its `Info.plist` or Android manifest, so an app that restricts orientation
/// in code, or sets its own system UI mode, can set them again in
/// [onExitFullScreen]. Set [allowFullScreen] to false to hide the button.
///
/// ## Loading and errors
///
/// A spinner is shown while the video loads or buffers. If it fails to load,
/// an error message with a Retry button replaces it; supply [errorBuilder] to
/// show your own UI instead.
///
/// ## Changing the source
///
/// Passing a different [source] loads the new video, keeping the mute
/// setting. Changing only the headers of a [VideoSource.uri] — a refreshed
/// auth token, say — does not interrupt the video that is playing; the new
/// headers are used the next time it loads.
///
/// ## Hidden players
///
/// The video pauses when the player is hidden: when a full-screen route such
/// as a `VideoViewerScreen` finishes covering it, or when it sits in a tab
/// of an [IndexedStack] or tab scaffold that is switched away from. It does
/// not resume by itself when it is shown again. Dialogs, menus and other
/// routes that leave it visible don't pause it, and nor does its own
/// full-screen button.
class VideoViewerWidget extends StatefulWidget {
  /// Creates a [VideoViewerWidget].
  ///
  /// [source] is the video to play.
  const VideoViewerWidget({
    super.key,
    required this.source,
    this.autoPlay = false,
    this.looping = false,
    this.errorBuilder,
    this.errorMessage = 'Could not load video',
    this.allowFullScreen = true,
    this.onExitFullScreen,
  });

  /// The video to play.
  final VideoSource source;

  /// Whether playback starts as soon as the video has loaded. Browsers may
  /// block this for videos with sound until the user interacts with the page.
  final bool autoPlay;

  /// Whether the video starts again from the beginning when it ends.
  final bool looping;

  /// Optional builder for an error UI shown in place of the video when it
  /// fails to load. Receives a description of the failure.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Message shown by the default error UI.
  final String errorMessage;

  /// Whether the controls include a button that shows the video full screen.
  final bool allowFullScreen;

  /// Called when full screen closes, after the system bars are back in
  /// edge-to-edge mode and orientation is back to the app's declared
  /// settings. Re-apply your own there if the app sets them in code.
  final VoidCallback? onExitFullScreen;

  @override
  State<VideoViewerWidget> createState() => _VideoViewerWidgetState();
}

class _VideoViewerWidgetState extends State<VideoViewerWidget> {
  // The screen-on switch is app-wide, so it stays on while any player plays.
  static int _playingCount = 0;
  // Null when the source can't be opened at all on this platform. [_loadError]
  // says why, or why a player that was created then failed to load.
  VideoPlayerController? _controller;
  Object? _loadError;

  // Rebuilds wait for these to change rather than for every position update;
  // the player view follows the rest itself.
  bool _isInitialized = false;
  bool _hasError = false;

  // The volume to go back to when the video is unmuted.
  double _volumeBeforeMute = 1;

  bool _isHoldingWakelock = false;

  // The full-screen page while it is open. The video shows there instead of
  // here: on web it is a single HTML element, which can't be in two places.
  Route<void>? _fullScreenRoute;

  // Turned off by Flutter for a subtree that can't be seen: a route fully
  // covered by an opaque one, or an inactive tab.
  ValueListenable<TickerModeData>? _tickerMode;

  bool get _isShown => _tickerMode?.value.enabled ?? true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerMode = TickerMode.getValuesNotifier(context);
    if (tickerMode == _tickerMode) return;
    _tickerMode?.removeListener(_onTickerModeChanged);
    _tickerMode = tickerMode..addListener(_onTickerModeChanged);
    _onTickerModeChanged();
  }

  void _onTickerModeChanged() {
    // Its own full-screen page covers this one, but is showing the video.
    if (!_isShown && _fullScreenRoute == null) _controller?.pause();
  }

  @override
  void didUpdateWidget(covariant VideoViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameVideo(oldWidget.source, widget.source)) {
      _reload();
    } else if (oldWidget.looping != widget.looping) {
      _controller?.setLooping(widget.looping);
    }
  }

  @override
  void dispose() {
    _tickerMode?.removeListener(_onTickerModeChanged);
    _holdWakelock(false);
    final controller = _controller;
    if (_fullScreenRoute == null) {
      controller?.dispose();
    } else {
      // The full-screen page is still showing the video.
      _closeFullScreen(then: () => controller?.dispose());
    }
    super.dispose();
  }

  // New headers alone (a refreshed auth token, say) are not a new video, and
  // must not restart the one that is playing.
  static bool _isSameVideo(VideoSource a, VideoSource b) =>
      a is VideoUriSource && b is VideoUriSource ? a.uri == b.uri : a == b;

  void _load({double volume = 1}) {
    _controller = null;
    _loadError = null;
    _isInitialized = false;
    _hasError = false;
    final VideoPlayerController controller;
    try {
      controller = switch (widget.source) {
        VideoUriSource(:final uri, :final headers) =>
          VideoPlayerController.networkUrl(
            uri,
            httpHeaders: headers ?? const <String, String>{},
          ),
        VideoFileSource(:final path) => file_loader.fileVideoController(path),
        VideoAssetSource(:final name, :final package) =>
          VideoPlayerController.asset(name, package: package),
      };
    } on UnsupportedError catch (error) {
      // File sources can't be opened on web.
      _loadError = error;
      return;
    }
    _controller = controller;
    controller.addListener(() => _onValueChanged(controller));
    controller.setLooping(widget.looping);
    controller.setVolume(volume);
    controller
        .initialize()
        .then((_) {
          // Ignore a video that was replaced or disposed while loading.
          if (!mounted || controller != _controller) return;
          if (widget.autoPlay && _isShown) controller.play();
        })
        .catchError((Object error) {
          // Most failures also arrive through the controller's value, but
          // one when the player is created (a missing asset, say) doesn't.
          if (!mounted || controller != _controller) return;
          if (controller.value.hasError) return;
          setState(() => _loadError = error);
        });
  }

  void _reload() {
    final old = _controller;
    _holdWakelock(false);
    setState(() {
      // A muted video stays muted across a retry or a change of source.
      _load(volume: old?.value.volume ?? 1);
    });
    // The old player is still in the tree until this frame has built, here
    // or on the full-screen page.
    _closeFullScreen(then: () => old?.dispose());
  }

  void _onValueChanged(VideoPlayerController controller) {
    // The full-screen page can outlive this widget by a frame.
    if (!mounted || controller != _controller) return;
    final value = controller.value;
    _holdWakelock(value.isPlaying);
    if (value.isInitialized != _isInitialized || value.hasError != _hasError) {
      setState(() {
        _isInitialized = value.isInitialized;
        _hasError = value.hasError;
      });
    }
    // The error, and its Retry button, show inline.
    if (value.hasError && _fullScreenRoute != null) _closeFullScreen();
  }

  void _holdWakelock(bool hold) {
    if (hold == _isHoldingWakelock) return;
    _isHoldingWakelock = hold;
    _playingCount += hold ? 1 : -1;
    // Only the first player to start and the last to stop flip the switch.
    if (_playingCount == (hold ? 1 : 0)) {
      // Keeping the screen on is a nicety; the video plays on if it fails.
      WakelockPlus.toggle(enable: hold).ignore();
    }
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null) return;
    final volume = controller.value.volume;
    if (volume == 0) {
      controller.setVolume(_volumeBeforeMute);
    } else {
      _volumeBeforeMute = volume;
      controller.setVolume(0);
    }
  }

  Future<void> _openFullScreen(VideoPlayerController controller) async {
    final route = PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => FullScreenVideo(
        controller: controller,
        onToggleMute: _toggleMute,
        onExit: widget.onExitFullScreen,
      ),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
    setState(() => _fullScreenRoute = route);
    Navigator.of(context, rootNavigator: true).push(route).ignore();
    // The page shows the video until it has faded out, and on web the video
    // can only be in one place.
    await route.completed;
    if (mounted && _fullScreenRoute == route) {
      setState(() => _fullScreenRoute = null);
    }
  }

  // Closes the full-screen page after this frame, since it may be called
  // while building, then runs [then].
  void _closeFullScreen({VoidCallback? then}) {
    final route = _fullScreenRoute;
    _fullScreenRoute = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route != null && route.isActive) route.navigator?.removeRoute(route);
      then?.call();
    });
  }

  Widget _buildError(BuildContext context, Object description) {
    final errorBuilder = widget.errorBuilder;
    if (errorBuilder != null) return errorBuilder(context, description);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(
              widget.errorMessage,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _reload,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final loadError = _loadError;
    final Widget child;
    if (controller == null || loadError != null) {
      child = _buildError(context, loadError ?? widget.errorMessage);
    } else if (controller.value.errorDescription case final error?) {
      child = _buildError(context, error);
    } else if (!_isInitialized) {
      child = const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    } else if (_fullScreenRoute != null) {
      child = const SizedBox.expand();
    } else {
      child = VideoPlayerView(
        controller: controller,
        onToggleMute: _toggleMute,
        isFullScreen: false,
        onToggleFullScreen: widget.allowFullScreen
            ? () => _openFullScreen(controller)
            : null,
      );
    }
    return ColoredBox(color: Colors.black, child: child);
  }
}
