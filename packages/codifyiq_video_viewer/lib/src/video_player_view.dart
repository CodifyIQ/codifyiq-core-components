import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import 'video_controls.dart';

/// A loaded video with its controls over it.
///
/// Tapping shows or hides the controls, which hide themselves a few seconds
/// after playback starts or when something else on screen is tapped. On phones and tablets, double-tapping the left or
/// right half jumps back or forward ten seconds.
class VideoPlayerView extends StatefulWidget {
  /// Creates a view of the video that [controller] has loaded.
  const VideoPlayerView({
    super.key,
    required this.controller,
    required this.onToggleMute,
    required this.isFullScreen,
    required this.onToggleFullScreen,
  });

  /// The loaded video.
  final VideoPlayerController controller;

  /// Mutes or unmutes the video.
  final VoidCallback onToggleMute;

  /// Whether this view is the full-screen one.
  final bool isFullScreen;

  /// Enters or leaves full screen; null hides the full-screen button.
  final VoidCallback? onToggleFullScreen;

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  static const Duration _kControlsHideDelay = Duration(seconds: 3);
  static const Duration _kSeekStep = Duration(seconds: 10);
  static const Duration _kSeekFeedbackDuration = Duration(milliseconds: 600);

  bool _controlsVisible = true;
  Timer? _hideTimer;

  // Slider position while the user is dragging it, so the thumb follows the
  // finger instead of snapping back to the playback position.
  double? _scrubValue;

  bool _wasPlaying = false;

  // Where the last double tap landed, and which way the feedback for the
  // jump it made points (-1 back, 1 forward) while it is on screen.
  double _doubleTapX = 0;
  int? _seekFeedback;
  Timer? _seekFeedbackTimer;

  VideoPlayerController get _controller => widget.controller;

  // Phones and tablets have hardware volume buttons, and double tap is how
  // their video apps seek. A desktop double click would only delay every
  // single click.
  static bool get _isTouchPlatform => switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    _wasPlaying = _controller.value.isPlaying;
    _controller.addListener(_onValueChanged);
    if (_wasPlaying) _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != _controller) {
      oldWidget.controller.removeListener(_onValueChanged);
      _controller.addListener(_onValueChanged);
      _wasPlaying = _controller.value.isPlaying;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onValueChanged);
    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    super.dispose();
  }

  // Whenever playback starts, by a button, autoplay or the other view of the
  // same video, show the controls for a moment before they hide.
  void _onValueChanged() {
    final isPlaying = _controller.value.isPlaying;
    if (isPlaying && !_wasPlaying) {
      setState(() => _controlsVisible = true);
      _scheduleHide();
    }
    _wasPlaying = isPlaying;
  }

  void _pause() {
    _hideTimer?.cancel();
    _controller.pause();
    setState(() => _controlsVisible = true);
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _hideControls() {
    if (!_controlsVisible) return;
    _hideTimer?.cancel();
    setState(() => _controlsVisible = false);
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_kControlsHideDelay, () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _seekFromDoubleTap() {
    // The view has been laid out by the time it is tapped.
    final direction = _doubleTapX < context.size!.width / 2 ? -1 : 1;
    final value = _controller.value;
    final target = value.position + _kSeekStep * direction;
    _controller.seekTo(
      target < Duration.zero
          ? Duration.zero
          : target > value.duration
          ? value.duration
          : target,
    );
    _seekFeedbackTimer?.cancel();
    setState(() => _seekFeedback = direction);
    _seekFeedbackTimer = Timer(_kSeekFeedbackDuration, () {
      if (mounted) setState(() => _seekFeedback = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        // Paused and finished videos keep their controls on screen.
        final showControls = _controlsVisible || !value.isPlaying;
        final seekFeedback = _seekFeedback;
        // Nothing to seek within until the length is known, e.g. for a live
        // stream.
        final canDoubleTapSeek =
            _isTouchPlatform && value.duration > Duration.zero;
        // Paused and finished videos still keep their controls.
        return TapRegion(
          onTapOutside: (_) => _hideControls(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                onDoubleTapDown: canDoubleTapSeek
                    ? (details) => _doubleTapX = details.localPosition.dx
                    : null,
                onDoubleTap: canDoubleTapSeek ? _seekFromDoubleTap : null,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: value.aspectRatio,
                    // On web the video is an HTML platform view, which would
                    // otherwise win every tap on it.
                    child: IgnorePointer(child: VideoPlayer(_controller)),
                  ),
                ),
              ),
              if (value.isBuffering && value.isPlaying)
                const IgnorePointer(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              if (seekFeedback != null)
                IgnorePointer(
                  child: Align(
                    alignment: Alignment(seekFeedback * 0.6, 0),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          seekFeedback < 0 ? Icons.replay_10 : Icons.forward_10,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
              IgnorePointer(
                ignoring: !showControls,
                child: AnimatedOpacity(
                  opacity: showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: VideoControls(
                    value: value,
                    scrubValue: _scrubValue,
                    // The player restarts a finished video from the beginning
                    // by itself.
                    onPlay: _controller.play,
                    onPause: _pause,
                    onToggleMute: () {
                      widget.onToggleMute();
                      _scheduleHide();
                    },
                    onVolumeChanged: _isTouchPlatform
                        ? null
                        : (volume) {
                            _hideTimer?.cancel();
                            _controller.setVolume(volume);
                          },
                    onVolumeChangeEnd: (_) {
                      if (value.isPlaying) _scheduleHide();
                    },
                    onScrub: (fraction) {
                      _hideTimer?.cancel();
                      setState(() => _scrubValue = fraction);
                    },
                    onScrubEnd: (fraction) {
                      _controller.seekTo(value.duration * fraction);
                      setState(() => _scrubValue = null);
                      if (value.isPlaying) _scheduleHide();
                    },
                    isFullScreen: widget.isFullScreen,
                    onToggleFullScreen: widget.onToggleFullScreen,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
