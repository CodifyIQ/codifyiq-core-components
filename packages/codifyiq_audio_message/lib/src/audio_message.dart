import 'package:flutter/material.dart';

import 'audio_message_controller.dart';

/// A self-contained audio message player widget.
///
/// Displays a play/pause button, a scrubbing [Slider], and an
/// elapsed / total duration readout. Handles loading, playing, paused,
/// and error states using theme-aware colors.
///
/// Supply a [controller] to share playback state across multiple widgets
/// (e.g., to stop one track when another starts). Omit it to let the
/// widget create and manage its own [AudioMessageController] lifecycle.
///
/// ```dart
/// AudioMessageWidget(
///   url: 'https://example.com/audio.mp3',
/// )
/// ```
class AudioMessageWidget extends StatefulWidget {
  /// Creates an [AudioMessageWidget].
  ///
  /// [url] is the audio source — an HTTP/HTTPS URL or a local file path.
  /// Ignored when [controller] is supplied; ensure they match to avoid
  /// confusion.
  const AudioMessageWidget({
    super.key,
    required this.url,
    this.controller,
    this.errorLabel = 'Could not load audio',
    this.playTooltip = 'Play',
    this.pauseTooltip = 'Pause',
    this.retryTooltip = 'Retry',
  });

  /// Audio source URL or file path. Ignored when [controller] is provided.
  final String url;

  /// Optional external controller. When omitted the widget creates and
  /// disposes its own [AudioMessageController].
  final AudioMessageController? controller;

  /// Label shown below the error icon. Defaults to `'Could not load audio'`.
  final String errorLabel;

  /// Tooltip for the play button. Defaults to `'Play'`.
  final String playTooltip;

  /// Tooltip for the pause button. Defaults to `'Pause'`.
  final String pauseTooltip;

  /// Tooltip for the retry button shown on error. Defaults to `'Retry'`.
  final String retryTooltip;

  @override
  State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  late AudioMessageController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    assert(
      widget.controller == null || widget.controller!.url == widget.url,
      'url is ignored when controller is provided; ensure they match or omit url.',
    );
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = AudioMessageController(widget.url);
      _ownsController = true;
    }
  }

  @override
  void didUpdateWidget(AudioMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newExternal = widget.controller;

    if (newExternal != null) {
      // Switching to (or staying on) an external controller.
      if (_ownsController) {
        _controller.dispose();
        _ownsController = false;
      }
      _controller = newExternal;
    } else if (!_ownsController) {
      // Switching from external to owned.
      _controller = AudioMessageController(widget.url);
      _ownsController = true;
    } else if (widget.url != oldWidget.url) {
      // Still owned but URL changed — recreate for the new source.
      _controller.dispose();
      _controller = AudioMessageController(widget.url);
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        final isInteractive =
            state != AudioPlaybackState.idle &&
            state != AudioPlaybackState.error;

        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  _LeadingButton(
                    state: state,
                    primaryColor: colorScheme.primary,
                    errorColor: colorScheme.error,
                    onPlay: () {
                      _controller.play();
                    },
                    onPause: () {
                      _controller.pause();
                    },
                    playTooltip: widget.playTooltip,
                    pauseTooltip: widget.pauseTooltip,
                    retryTooltip: widget.retryTooltip,
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                      ),
                      child: Slider(
                        value: _controller.progress,
                        onChanged: isInteractive
                            ? (v) => _controller.seek(v)
                            : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${_fmt(_controller.position)} / ${_fmt(_controller.duration)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              if (state == AudioPlaybackState.error)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                  child: Text(
                    widget.errorLabel,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The leading control — spinner while loading, play/pause while ready,
/// error icon on failure.
class _LeadingButton extends StatelessWidget {
  const _LeadingButton({
    required this.state,
    required this.primaryColor,
    required this.errorColor,
    required this.onPlay,
    required this.onPause,
    required this.playTooltip,
    required this.pauseTooltip,
    required this.retryTooltip,
  });

  final AudioPlaybackState state;
  final Color primaryColor;
  final Color errorColor;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final String playTooltip;
  final String pauseTooltip;
  final String retryTooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: switch (state) {
        AudioPlaybackState.loading => Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: primaryColor,
            ),
          ),
        ),
        AudioPlaybackState.error => IconButton(
          icon: const Icon(Icons.error_outline),
          color: errorColor,
          iconSize: 28,
          onPressed: onPlay,
          tooltip: retryTooltip,
        ),
        AudioPlaybackState.playing => IconButton(
          icon: const Icon(Icons.pause),
          color: primaryColor,
          iconSize: 28,
          onPressed: onPause,
          tooltip: pauseTooltip,
        ),
        _ => IconButton(
          icon: const Icon(Icons.play_arrow),
          color: primaryColor,
          iconSize: 28,
          onPressed: onPlay,
          tooltip: playTooltip,
        ),
      },
    );
  }
}
