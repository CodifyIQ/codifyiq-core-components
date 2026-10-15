import 'package:material_ui/material_ui.dart';

import 'audio_message_controller.dart';
import 'audio_message_source.dart';

/// An audio message player.
///
/// Displays a play/pause button, a scrubbing [Slider], and an
/// elapsed / total duration readout. Handles loading, playing, paused,
/// and error states using theme-aware colors.
///
/// On its own it plays [source] with a controller it creates and disposes,
/// so playback stops when the widget is removed:
///
/// ```dart
/// AudioMessageWidget(
///   source: AudioMessageSource.uri(Uri.parse('https://example.com/note.m4a')),
///   duration: const Duration(seconds: 42),
/// )
/// ```
///
/// In a list of messages, such as a chat, give every player the same
/// [controller], owned by the screen, and each message's [id]. Then only one
/// message plays at a time, and playback continues when a player scrolls out
/// of view and is disposed; scrolled back, a player with the same [id] and
/// [source] shows the current position.
class AudioMessageWidget extends StatefulWidget {
  /// Creates an [AudioMessageWidget].
  ///
  /// [source] is the audio to play.
  const AudioMessageWidget({
    super.key,
    required this.source,
    this.id,
    this.controller,
    this.duration,
    this.color,
    this.textStyle,
    this.errorLabel = 'Could not load audio',
    this.playTooltip = 'Play',
    this.pauseTooltip = 'Pause',
    this.retryTooltip = 'Retry',
  });

  /// The audio to play.
  final AudioMessageSource source;

  /// Identifies this message to a shared [controller], for example the chat
  /// message's id, so a new player for the same message picks up its
  /// playback. Without it, each player is a message of its own.
  final Object? id;

  /// A controller shared with other players, which plays one message at a
  /// time. When omitted the widget creates and disposes its own.
  final AudioMessageController? controller;

  /// The audio's length, shown until the source has loaded. Without it the
  /// length reads `00:00` until the first play.
  final Duration? duration;

  /// Colour of the play button and the slider. Defaults to the theme's
  /// primary colour.
  final Color? color;

  /// Style of the elapsed / total readout. Defaults to the theme's
  /// `bodySmall` in `onSurfaceVariant`.
  final TextStyle? textStyle;

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
  AudioMessageController? _ownController;
  late AudioMessageController _controller;
  // Stands in for a missing id, so each such player is its own message.
  final _defaultId = Object();
  bool _wasCurrent = false;

  Object _idOf(AudioMessageWidget widget) => widget.id ?? _defaultId;

  // Whether the controller is on this message, with this source: a message
  // whose source changed, such as from a local file to its uploaded URL, is
  // a new one to play.
  bool get _isCurrent =>
      _controller.currentId == _idOf(widget) &&
      _controller.currentSource == widget.source;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _controller =
        widget.controller ?? (_ownController ??= AudioMessageController());
    _wasCurrent = _isCurrent;
    _controller.addListener(_onControllerChanged);
  }

  // A shared controller notifies on every position update of whichever
  // message is playing; only that message's player, and one that just
  // stopped being it, need to rebuild.
  void _onControllerChanged() {
    final isCurrent = _isCurrent;
    if (isCurrent || _wasCurrent) setState(() {});
    _wasCurrent = isCurrent;
  }

  @override
  void didUpdateWidget(AudioMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.controller ?? _ownController;
    // The old message stops, rather than playing on behind the new one.
    if (old != null &&
        old.currentId == _idOf(oldWidget) &&
        old.currentSource == oldWidget.source &&
        (_idOf(oldWidget) != _idOf(widget) ||
            oldWidget.source != widget.source)) {
      old.pause();
    }
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onControllerChanged);
      if (widget.controller != null) {
        _ownController?.dispose();
        _ownController = null;
      }
      _attach();
    } else {
      _wasCurrent = _isCurrent;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _ownController?.dispose();
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
    final color = widget.color ?? colorScheme.primary;
    final controller = _controller;
    final id = _idOf(widget);

    // A shared controller may be playing another message.
    final isCurrent = _isCurrent;
    final state = isCurrent ? controller.state : AudioPlaybackState.idle;
    final position = isCurrent ? controller.position : Duration.zero;
    final duration = isCurrent && controller.duration > Duration.zero
        ? controller.duration
        : widget.duration ?? Duration.zero;
    final isInteractive =
        state != AudioPlaybackState.idle && state != AudioPlaybackState.error;

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
                primaryColor: color,
                errorColor: colorScheme.error,
                onPlay: () => controller.play(id, widget.source),
                onPause: controller.pause,
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
                    value: isCurrent ? controller.progress : 0,
                    activeColor: color,
                    inactiveColor: color.withValues(alpha: 0.3),
                    onChanged: isInteractive ? controller.seek : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${_fmt(position)} / ${_fmt(duration)}',
                  style:
                      (widget.textStyle ??
                              textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ))
                          ?.copyWith(
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
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
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
