import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

import '_video_controller_file_io.dart'
    if (dart.library.js_interop) '_video_controller_file_web.dart';
import 'video_source.dart';

// App-lifetime cache for video metadata (duration).
// Avoids re-initialising a VideoPlayerController on every widget mount just
// to read the duration for a source we have already probed.
final class _MetadataCache {
  _MetadataCache._();
  static final instance = _MetadataCache._();
  static const _maxEntries = 50;
  final _durations = <String, String>{};
  String? getDuration(String key) {
    final value = _durations.remove(key);
    if (value != null) _durations[key] = value; // re-insert to mark as most-recently-used
    return value;
  }

  void putDuration(String key, String duration) {
    _durations.remove(key); // ensure re-insertion moves it to end
    if (_durations.length >= _maxEntries) _durations.remove(_durations.keys.first);
    _durations[key] = duration;
  }
}

// Default corner radii for chat bubbles.
const _kRadius = Radius.circular(16);
const _kTailRadius = Radius.circular(4);

// Add fields here to extend the equality-checked rebuild gate (e.g. position for a progress bar).
typedef _PlayerSnapshot = ({bool isPlaying});

_PlayerSnapshot _snapshotOf(VideoPlayerController ctrl) =>
    (isPlaying: ctrl.value.isPlaying);


/// A video message widget with tap-to-play inline playback.
///
/// Shows a thumbnail with a play overlay until the user taps, then switches
/// to an inline [VideoPlayer]. The [VideoPlayerController] lifecycle is
/// managed internally.
///
/// ## Thumbnail resolution order
///
/// 1. [thumbnailBuilder] — fully custom widget, skips all other logic.
/// 2. [thumbnailUrl] — network image.
/// 3. [errorBuilder] / placeholder when all sources fail.
///
/// ## Source routing
///
/// Pass a [VideoSource] variant to specify the source type explicitly:
/// - [VideoSource.network] — HTTP/HTTPS URL, with optional auth headers
/// - [VideoSource.asset] — Flutter asset declared in `pubspec.yaml`
/// - [VideoSource.file] — local file path (native only)
///
/// ## Duration badge
///
/// Pass a pre-formatted string via [duration] (e.g. `'1:23'`) to show a badge
/// without any background I/O. Set [probeDuration] to `true` to have the
/// widget probe [source] itself — use this only for asset / file sources or
/// single-video screens, not for network sources in a scrolling list.
class VideoMessageWidget extends StatefulWidget {
  /// The video source. Use [VideoSource.network], [VideoSource.asset], or
  /// [VideoSource.file] to disambiguate the source type explicitly.
  final VideoSource source;

  /// Optional network URL for the thumbnail image.
  ///
  /// Preferred over local generation. When provided, no `video_thumbnail`
  /// call is made.
  final String? thumbnailUrl;

  /// Pre-formatted duration string displayed as a badge (e.g. `'1:23'`).
  ///
  /// Takes precedence over [probeDuration]. When both are omitted no badge
  /// is shown.
  final String? duration;

  /// Whether to probe [source] in the background to discover its duration
  /// and display it as a badge automatically.
  ///
  /// Defaults to `false`. Probing is silently skipped for [VideoSource.network]
  /// regardless of this flag — initialising a network controller opens a
  /// connection and buffers initial bytes, which is unsafe to do for every
  /// item in a chat list. Prefer passing a pre-formatted [duration] for
  /// network videos, and reserve [probeDuration] for [VideoSource.asset] /
  /// [VideoSource.file] sources or isolated single-video screens.
  ///
  /// Has no effect when [duration] is provided.
  final bool probeDuration;

  /// Aspect ratio of the video container. Defaults to `16 / 9`.
  final double aspectRatio;

  /// Whether this message was sent by the current user.
  ///
  /// Controls which corner receives the tail radius when [isLastInGroup] is
  /// true — bottom-right for sent, bottom-left for received. Has no effect
  /// when [borderRadius] is set explicitly.
  final bool isSentByMe;

  /// Whether this is the last (or only) message in a consecutive run from the
  /// same sender.
  ///
  /// When true, the sender-side bottom corner is given a tighter radius to
  /// form the chat bubble tail. When false (middle of a group), all corners
  /// are uniformly rounded. Has no effect when [borderRadius] is set
  /// explicitly.
  final bool isLastInGroup;

  /// Explicit border radius for the video container.
  ///
  /// When provided, overrides the radius computed from [isSentByMe] and
  /// [isLastInGroup].
  final BorderRadiusGeometry? borderRadius;

  /// Builder for a fully custom video player widget.
  ///
  /// Called with the initialized [VideoPlayerController] instead of the default
  /// [VideoPlayer]. Use this to wrap the player in Chewie, push a fullscreen
  /// overlay, or add playback controls without forking the widget.
  ///
  /// The controller is already initialized and playing when this is called.
  final Widget Function(BuildContext, VideoPlayerController)? videoBuilder;

  /// Replaces the default semi-transparent circular play icon overlay.
  final Widget? overlay;

  /// Builder for a fully custom thumbnail widget.
  ///
  /// When set, [thumbnailUrl] is skipped.
  final WidgetBuilder? thumbnailBuilder;

  /// Builder for the thumbnail-loading state.
  ///
  /// Shown while [thumbnailUrl] is downloading. Defaults to a
  /// [CircularProgressIndicator] on a surface-coloured background.
  final WidgetBuilder? loadingBuilder;

  /// Builder for the thumbnail-error state.
  ///
  /// Shown when [thumbnailUrl] fails to load. Defaults to a play-arrow icon
  /// on a surface-coloured background.
  final WidgetBuilder? errorBuilder;

  /// HTTP headers forwarded when fetching [thumbnailUrl].
  ///
  /// For video request headers (e.g. auth tokens on a signed CDN URL), set
  /// [VideoSource.network]'s `headers` parameter instead.
  final Map<String, String>? thumbnailHeaders;

  /// Creates a [VideoMessageWidget].
  const VideoMessageWidget({
    super.key,
    required this.source,
    this.thumbnailUrl,
    this.duration,
    this.probeDuration = false,
    this.aspectRatio = 16 / 9,
    this.isSentByMe = false,
    this.isLastInGroup = true,
    this.borderRadius,
    this.videoBuilder,
    this.overlay,
    this.thumbnailBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.thumbnailHeaders,
  });

  @override
  State<VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<VideoMessageWidget> {
  VideoPlayerController? _controller;
  // Holds a pre-initialized controller from _probeDuration so the first tap
  // can start playback immediately without a second initialization round-trip.
  VideoPlayerController? _probeController;
  bool _initializing = false;
  _PlayerSnapshot? _lastSnapshot;
  String? _detectedDuration;

  String? get _effectiveDuration => widget.duration ?? _detectedDuration;

  String get _sourceKey => switch (widget.source) {
    VideoNetworkSource(:final uri) => uri.toString(),
    VideoAssetSource(:final path) => path,
    VideoFileSource(:final path) => path,
  };

  BorderRadiusGeometry get _effectiveBorderRadius {
    if (widget.borderRadius != null) return widget.borderRadius!;
    if (!widget.isLastInGroup) return const BorderRadius.all(_kRadius);
    return widget.isSentByMe
        ? const BorderRadius.only(
            topLeft: _kRadius,
            topRight: _kRadius,
            bottomLeft: _kRadius,
            bottomRight: _kTailRadius,
          )
        : const BorderRadius.only(
            topLeft: _kRadius,
            topRight: _kRadius,
            bottomLeft: _kTailRadius,
            bottomRight: _kRadius,
          );
  }

  @override
  void initState() {
    super.initState();
    // Defer background work to after the first frame so the build phase is
    // not contended by concurrent I/O. Widgets scrolled past before the next
    // frame is drawn will have mounted = false by the time the callback fires,
    // so no work starts for items that were never actually visible.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initBackground();
    });
  }

  void _initBackground() {
    if (widget.duration == null &&
        widget.probeDuration &&
        widget.source is! VideoNetworkSource) {
      final cachedDuration = _MetadataCache.instance.getDuration(_sourceKey);
      if (cachedDuration != null) {
        setState(() => _detectedDuration = cachedDuration);
      } else {
        _probeDuration();
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onUpdate);
    _controller?.dispose();
    _probeController?.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (!mounted) return;
    final ctrl = _controller;
    if (ctrl == null) return;
    final snapshot = _snapshotOf(ctrl);
    if (snapshot != _lastSnapshot) {
      _lastSnapshot = snapshot;
      setState(() {});
    }
  }

  VideoPlayerController _makeController() => switch (widget.source) {
    VideoNetworkSource(:final uri, :final headers) =>
      VideoPlayerController.networkUrl(uri, httpHeaders: headers ?? const {}),
    VideoAssetSource(:final path) => VideoPlayerController.asset(path),
    VideoFileSource(:final path) => fileVideoController(path),
  };

  Future<void> _probeDuration() async {
    final probe = _makeController();
    bool saved = false;
    try {
      await probe.initialize();
      if (!mounted) return;
      final d = probe.value.duration;
      if (d != Duration.zero) {
        final m = d.inMinutes;
        final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
        final label = '$m:$s';
        _MetadataCache.instance.putDuration(_sourceKey, label);
        setState(() => _detectedDuration = label);
      }
      // Keep the initialized controller alive for reuse on first tap.
      // If the user already tapped while we were probing, discard it instead.
      if (_controller == null) {
        _probeController = probe;
        saved = true;
      }
    } catch (_) {
      // Duration unavailable — badge simply won't appear.
    } finally {
      if (!saved) await probe.dispose();
    }
  }

  void _onTap() {
    final ctrl = _controller;
    if (ctrl != null && ctrl.value.isInitialized) {
      ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
      return;
    }
    if (_initializing) return;

    // Reuse the probe controller when available — avoids a second initialization
    // round-trip for sources that were already probed for duration.
    final probe = _probeController;
    if (probe != null) {
      _probeController = null;
      setState(() => _controller = probe);
      probe.addListener(_onUpdate);
      probe.play();
      return;
    }

    setState(() => _initializing = true);
    final newCtrl = _makeController();
    newCtrl.initialize().then((_) {
      if (!mounted) {
        newCtrl.dispose();
        return;
      }
      setState(() {
        _controller = newCtrl;
        _initializing = false;
      });
      newCtrl.addListener(_onUpdate);
      newCtrl.play();
    }).catchError((Object e, StackTrace s) {
      if (mounted) setState(() => _initializing = false);
      newCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    final initialized = ctrl != null && ctrl.value.isInitialized;

    return ClipRRect(
      borderRadius: _effectiveBorderRadius,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (initialized)
              widget.videoBuilder != null
                  ? widget.videoBuilder!(context, ctrl)
                  : VideoPlayer(ctrl)
            else
              _buildThumbnail(context),
            if (!initialized || !ctrl.value.isPlaying)
              _buildPlayOverlay(context, isLoading: _initializing),
            if (_effectiveDuration != null && !initialized)
              Positioned(
                left: 8,
                bottom: 8,
                child: _DurationBadge(_effectiveDuration!),
              ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    if (widget.thumbnailBuilder != null) {
      return widget.thumbnailBuilder!(context);
    }

    final url = widget.thumbnailUrl;
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        headers: widget.thumbnailHeaders,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _buildLoadingPlaceholder(context),
        errorBuilder: (_, _, _) => _buildErrorPlaceholder(context),
      );
    }

    return _buildDefaultPlaceholder(context);
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    if (widget.loadingBuilder != null) return widget.loadingBuilder!(context);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          strokeCap: StrokeCap.round,
        ),
      ),
    );
  }

  // No thumbnail source available — not an error, just no poster image.
  // Always shows the default play-icon placeholder regardless of errorBuilder.
  Widget _buildDefaultPlaceholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Center(
        child: Icon(
          Icons.play_arrow_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  // A thumbnail source existed but actively failed (URL 404, generation threw).
  Widget _buildErrorPlaceholder(BuildContext context) {
    if (widget.errorBuilder != null) return widget.errorBuilder!(context);
    return _buildDefaultPlaceholder(context);
  }

  Widget _buildPlayOverlay(BuildContext context, {required bool isLoading}) {
    if (isLoading) {
      return const ColoredBox(
        color: Colors.black26,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    if (widget.overlay != null) return widget.overlay!;
    return Center(
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Colors.white),
      ),
    );
  }
}
