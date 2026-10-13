import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import 'video_duration.dart';

/// The overlay: a large play/pause button over the video and a bottom bar
/// with the scrubber, times, mute button, and optional volume slider and
/// full-screen button.
class VideoControls extends StatelessWidget {
  /// Creates the controls for a video whose state is [value].
  const VideoControls({
    super.key,
    required this.value,
    required this.scrubValue,
    required this.onPlay,
    required this.onPause,
    required this.onToggleMute,
    required this.onVolumeChanged,
    required this.onVolumeChangeEnd,
    required this.onScrub,
    required this.onScrubEnd,
    required this.isFullScreen,
    required this.onToggleFullScreen,
  });

  /// The video's current state.
  final VideoPlayerValue value;

  /// Where the scrubber thumb is while it is being dragged.
  final double? scrubValue;

  /// Starts or resumes playback.
  final VoidCallback onPlay;

  /// Pauses playback.
  final VoidCallback onPause;

  /// Mutes or unmutes the video.
  final VoidCallback onToggleMute;

  /// Sets the volume; null hides the volume slider.
  final ValueChanged<double>? onVolumeChanged;

  /// Called when the volume slider is let go.
  final ValueChanged<double> onVolumeChangeEnd;

  /// Called as the scrubber is dragged, with a fraction of the length.
  final ValueChanged<double> onScrub;

  /// Called when the scrubber is let go, with a fraction of the length.
  final ValueChanged<double> onScrubEnd;

  /// Whether the video is showing full screen, which picks the icon of the
  /// full-screen button.
  final bool isFullScreen;

  /// Enters or leaves full screen; null hides the full-screen button.
  final VoidCallback? onToggleFullScreen;

  @override
  Widget build(BuildContext context) {
    final duration = value.duration;
    final progress = duration > Duration.zero
        ? (value.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final shown = scrubValue ?? progress;
    final isMuted = value.volume == 0;
    const timeStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              iconSize: 40,
              color: Colors.white,
              icon: Icon(
                value.isPlaying
                    ? Icons.pause
                    : value.isCompleted
                    ? Icons.replay
                    : Icons.play_arrow,
              ),
              tooltip: value.isPlaying
                  ? 'Pause'
                  : value.isCompleted
                  ? 'Replay'
                  : 'Play',
              onPressed: value.isPlaying ? onPause : onPlay,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white38,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  top: 16,
                  // The slider has no padding of its own, unlike the buttons.
                  right: onVolumeChanged != null && onToggleFullScreen == null
                      ? 12
                      : 0,
                ),
                child: Row(
                  children: [
                    Text(
                      formatVideoDuration(duration * shown),
                      style: timeStyle,
                    ),
                    // Unconstrained, a Slider grows to fill the height on
                    // offer and would cover the video.
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: Slider(
                          value: shown,
                          // Nothing to seek within until the length is
                          // known, e.g. for a live stream.
                          onChanged: duration > Duration.zero ? onScrub : null,
                          onChangeEnd: onScrubEnd,
                        ),
                      ),
                    ),
                    Text(formatVideoDuration(duration), style: timeStyle),
                    IconButton(
                      color: Colors.white,
                      icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up),
                      tooltip: isMuted ? 'Unmute' : 'Mute',
                      onPressed: onToggleMute,
                    ),
                    if (onVolumeChanged case final onVolumeChanged?)
                      SizedBox(
                        width: 80,
                        height: 40,
                        child: Slider(
                          value: value.volume,
                          semanticFormatterCallback: (volume) =>
                              'Volume ${(volume * 100).round()}%',
                          onChanged: onVolumeChanged,
                          onChangeEnd: onVolumeChangeEnd,
                        ),
                      ),
                    if (onToggleFullScreen case final onToggleFullScreen?)
                      IconButton(
                        color: Colors.white,
                        icon: Icon(
                          isFullScreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                        ),
                        tooltip: isFullScreen
                            ? 'Exit full screen'
                            : 'Full screen',
                        onPressed: onToggleFullScreen,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
