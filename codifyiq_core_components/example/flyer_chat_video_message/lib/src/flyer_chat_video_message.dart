import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

// video_thumbnail supports Android, iOS, and macOS only.
bool get _canGenerateThumbnail =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

// In-memory thumbnail cache shared across all widget instances for the
// app's lifetime — avoids re-running VideoThumbnail.thumbnailData on
// every rebuild or list scroll.
final class _VideoThumbnailCache {
  _VideoThumbnailCache._();
  static final instance = _VideoThumbnailCache._();

  final _store = <String, Uint8List>{};

  Uint8List? get(String key) => _store[key];
  void put(String key, Uint8List bytes) => _store[key] = bytes;
}

typedef _LocalTheme = ({
  TextStyle labelSmall,
  Color onSurface,
  BorderRadiusGeometry shape,
  Color surfaceContainerLow,
});

enum _ThumbnailState { loading, loaded, error }

/// A widget that renders a [VideoMessage] as a thumbnail with a play overlay.
///
/// This is a pure UI renderer. It does not implement video playback,
/// fullscreen viewing, or media gallery navigation.
///
/// ## Thumbnail resolution order
///
/// 1. `message.metadata['thumbnailUrl']` — backend-provided network thumbnail
///    (preferred; avoids local generation entirely).
/// 2. Locally generated via `video_thumbnail` (Android, iOS, macOS only).
/// 3. Error placeholder when both options fail.
///
/// ## Duration badge
///
/// Pass a pre-formatted duration string in `message.metadata['duration']`
/// (e.g. `'1:23'`). It is displayed as a badge in the bottom-left corner.
///
/// ## Customisation
///
/// Every visual layer is replaceable:
/// - [customVideoWidget] — replaces the entire content.
/// - [thumbnailBuilder] — replaces the thumbnail layer only.
/// - [loadingBuilder] / [errorBuilder] — replace the respective states.
/// - [overlay] — replaces the play icon.
class FlyerChatVideoMessage extends StatefulWidget {
  /// The video message data model.
  final VideoMessage message;

  /// Position of the message in the list.
  final int index;

  /// Border radius of the video container. Defaults to the chat theme shape.
  final BorderRadiusGeometry? borderRadius;

  /// Size constraints for the video container. Defaults to `maxHeight: 300`.
  final BoxConstraints? constraints;

  /// Replaces both the thumbnail and play overlay with a fully custom widget.
  ///
  /// When set, [thumbnailBuilder], [loadingBuilder], [errorBuilder], and
  /// [overlay] are all ignored.
  final Widget? customVideoWidget;

  /// Builder for a custom thumbnail widget.
  ///
  /// Return a widget representing the video content. When `null` the default
  /// thumbnail resolution logic applies.
  final Widget Function(BuildContext, VideoMessage)? thumbnailBuilder;

  /// Builder for the thumbnail-loading state.
  ///
  /// Shown while the thumbnail URL is downloading or local generation is in
  /// progress. Defaults to a `CircularProgressIndicator` on a solid
  /// placeholder background.
  final WidgetBuilder? loadingBuilder;

  /// Builder for the thumbnail-error state.
  ///
  /// Shown when all thumbnail sources have failed. Defaults to a
  /// `videocam_off` icon on a solid placeholder background.
  final WidgetBuilder? errorBuilder;

  /// Overlay rendered on top of the thumbnail to indicate this is a video.
  ///
  /// Defaults to a semi-transparent circular play button. Replace with
  /// `const SizedBox.shrink()` to remove the overlay entirely.
  final Widget? overlay;

  /// Background color used for the placeholder, loading, and error states.
  final Color? placeholderColor;

  /// Color of the `CircularProgressIndicator` during thumbnail loading.
  final Color? loadingIndicatorColor;

  /// Color of the overlay shown during video upload.
  final Color? uploadOverlayColor;

  /// Color of the `CircularProgressIndicator` during video upload.
  final Color? uploadIndicatorColor;

  /// Text style for the message timestamp and delivery status.
  final TextStyle? timeStyle;

  /// Background color for the time/status pill and duration badge.
  ///
  /// Defaults to `Colors.black` at 60 % opacity.
  final Color? badgeBackground;

  /// Whether to display the message timestamp. Defaults to `true`.
  final bool showTime;

  /// Whether to display the delivery status for sent messages. Defaults to `true`.
  final bool showStatus;

  /// Position of the timestamp and status pill. Defaults to [TimeAndStatusPosition.end].
  final TimeAndStatusPosition timeAndStatusPosition;

  /// Optional widget displayed above the thumbnail (e.g. reply preview or
  /// sender name). Requires a [LayoutBuilder] pass; only rendered when
  /// non-null.
  final Widget? topWidget;

  /// HTTP headers used when fetching the thumbnail from a network URL.
  final Map<String, String>? headers;

  /// Creates a [FlyerChatVideoMessage].
  const FlyerChatVideoMessage({
    super.key,
    required this.message,
    required this.index,
    this.borderRadius,
    this.constraints = const BoxConstraints(maxHeight: 300),
    this.customVideoWidget,
    this.thumbnailBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.overlay,
    this.placeholderColor,
    this.loadingIndicatorColor,
    this.uploadOverlayColor,
    this.uploadIndicatorColor,
    this.timeStyle,
    this.badgeBackground,
    this.showTime = true,
    this.showStatus = true,
    this.timeAndStatusPosition = TimeAndStatusPosition.end,
    this.topWidget,
    this.headers,
  });

  @override
  State<FlyerChatVideoMessage> createState() => _FlyerChatVideoMessageState();
}

class _FlyerChatVideoMessageState extends State<FlyerChatVideoMessage> {
  late double _aspectRatio;
  late _ThumbnailState _thumbnailState;
  Uint8List? _generatedThumbnail;
  late ChatController _chatController;

  String? get _thumbnailUrl =>
      widget.message.metadata?['thumbnailUrl'] as String?;

  String? get _videoDuration =>
      widget.message.metadata?['duration'] as String?;

  @override
  void initState() {
    super.initState();
    _chatController = context.read<ChatController>();

    final w = widget.message.width;
    final h = widget.message.height;
    _aspectRatio =
        (w != null && h != null && w > 0 && h > 0) ? w / h : 16 / 9;

    if (_thumbnailUrl != null) {
      _thumbnailState = _ThumbnailState.loaded;
    } else if (_canGenerateThumbnail) {
      _thumbnailState = _ThumbnailState.loading;
      _generateThumbnail();
    } else {
      // Web, Windows, Linux — video_thumbnail is unavailable; fall back to
      // the error placeholder (or consumer-supplied errorBuilder).
      _thumbnailState = _ThumbnailState.error;
    }
  }

  Future<void> _generateThumbnail() async {
    final source = widget.message.source;

    final cached = _VideoThumbnailCache.instance.get(source);
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _generatedThumbnail = cached;
        _thumbnailState = _ThumbnailState.loaded;
      });
      return;
    }

    try {
      final data = await VideoThumbnail.thumbnailData(
        video: source,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        quality: 75,
      );
      if (!mounted) return;
      if (data != null) _VideoThumbnailCache.instance.put(source, data);
      setState(() {
        _generatedThumbnail = data;
        _thumbnailState =
            data != null ? _ThumbnailState.loaded : _ThumbnailState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _thumbnailState = _ThumbnailState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.select(
      (ChatTheme t) => (
        labelSmall: t.typography.labelSmall,
        onSurface: t.colors.onSurface,
        shape: t.shape,
        surfaceContainerLow: t.colors.surfaceContainerLow,
      ),
    );
    final isSentByMe = context.read<UserID>() == widget.message.authorId;
    final textDirection = Directionality.of(context);

    final timeAndStatus = widget.showTime || (isSentByMe && widget.showStatus)
        ? _TimeAndStatus(
            time: widget.message.resolvedTime,
            status: widget.message.resolvedStatus,
            showTime: widget.showTime,
            showStatus: isSentByMe && widget.showStatus,
            backgroundColor: widget.badgeBackground ??
                Colors.black.withValues(alpha: 0.6),
            textStyle: widget.timeStyle ??
                theme.labelSmall.copyWith(color: Colors.white),
          )
        : null;

    return Semantics(
      label: _semanticLabel,
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? theme.shape,
        child: Container(
          constraints: widget.constraints,
          child: AspectRatio(
            aspectRatio: _aspectRatio,
            child: widget.topWidget != null
                ? LayoutBuilder(
                    builder: (context, layoutConstraints) => _buildStack(
                      layoutConstraints,
                      theme,
                      textDirection,
                      timeAndStatus,
                      isSentByMe,
                    ),
                  )
                : _buildStack(
                    null, theme, textDirection, timeAndStatus, isSentByMe),
          ),
        ),
      ),
    );
  }

  String get _semanticLabel {
    final buffer = StringBuffer('Video message');
    final name = widget.message.name;
    if (name != null) buffer.write(', $name');
    final duration = _videoDuration;
    if (duration != null) buffer.write(', duration $duration');
    return buffer.toString();
  }

  Widget _buildStack(
    BoxConstraints? layoutConstraints,
    _LocalTheme theme,
    TextDirection textDirection,
    _TimeAndStatus? timeAndStatus,
    bool isSentByMe,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildThumbnailLayer(theme),
        ExcludeSemantics(child: _buildPlayOverlay()),
        if (_chatController is UploadProgressMixin)
          _buildUploadProgress(theme),
        if (_videoDuration != null)
          Positioned.directional(
            textDirection: textDirection,
            start: 8,
            bottom: 8,
            child: _buildBadge(theme, _videoDuration!),
          ),
        if (widget.topWidget != null && layoutConstraints != null)
          Positioned.directional(
            textDirection: textDirection,
            start: 8,
            top: 8,
            child: Container(
              constraints:
                  BoxConstraints(maxWidth: layoutConstraints.maxWidth - 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: widget.badgeBackground ??
                    Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: widget.topWidget,
            ),
          ),
        if (timeAndStatus != null)
          Positioned.directional(
            textDirection: textDirection,
            bottom: 8,
            end: widget.timeAndStatusPosition == TimeAndStatusPosition.end ||
                    widget.timeAndStatusPosition ==
                        TimeAndStatusPosition.inline
                ? 8
                : null,
            start:
                widget.timeAndStatusPosition == TimeAndStatusPosition.start
                    ? 8
                    : null,
            child: timeAndStatus,
          ),
      ],
    );
  }

  // ── Thumbnail layer ────────────────────────────────────────────────────────

  Widget _buildThumbnailLayer(_LocalTheme theme) {
    if (widget.customVideoWidget != null) return widget.customVideoWidget!;
    if (widget.thumbnailBuilder != null) {
      return widget.thumbnailBuilder!(context, widget.message);
    }

    final thumbnailUrl = _thumbnailUrl;
    if (thumbnailUrl != null) {
      return Image.network(
        thumbnailUrl,
        fit: BoxFit.cover,
        headers: widget.headers,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _buildLoadingPlaceholder(theme),
        errorBuilder: (_, _, _) => _buildErrorPlaceholder(theme),
      );
    }

    return switch (_thumbnailState) {
      _ThumbnailState.loading => _buildLoadingPlaceholder(theme),
      _ThumbnailState.error => _buildErrorPlaceholder(theme),
      _ThumbnailState.loaded when _generatedThumbnail != null =>
        Image.memory(_generatedThumbnail!, fit: BoxFit.cover),
      _ => _buildErrorPlaceholder(theme),
    };
  }

  Widget _buildLoadingPlaceholder(_LocalTheme theme) {
    if (widget.loadingBuilder != null) return widget.loadingBuilder!(context);
    return ColoredBox(
      color: widget.placeholderColor ?? theme.surfaceContainerLow,
      child: Center(
        child: CircularProgressIndicator(
          color: widget.loadingIndicatorColor ??
              theme.onSurface.withValues(alpha: 0.8),
          strokeCap: StrokeCap.round,
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(_LocalTheme theme) {
    if (widget.errorBuilder != null) return widget.errorBuilder!(context);
    return ColoredBox(
      color: widget.placeholderColor ?? theme.surfaceContainerLow,
      child: Center(
        child: Icon(
          Icons.videocam_off_outlined,
          color: theme.onSurface.withValues(alpha: 0.5),
          size: 40,
        ),
      ),
    );
  }

  // ── Overlays ───────────────────────────────────────────────────────────────

  Widget _buildPlayOverlay() {
    if (widget.overlay != null) return widget.overlay!;
    return Center(
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
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

  Widget _buildBadge(_LocalTheme theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: widget.badgeBackground ?? Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.labelSmall.copyWith(color: Colors.white),
      ),
    );
  }

  Widget _buildUploadProgress(_LocalTheme theme) {
    return StreamBuilder<double>(
      stream: (_chatController as UploadProgressMixin)
          .getUploadProgress(widget.message.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data! >= 1) {
          return const SizedBox.shrink();
        }
        return Container(
          color: widget.uploadOverlayColor ??
              theme.surfaceContainerLow.withValues(alpha: 0.5),
          child: Center(
            child: CircularProgressIndicator(
              color: widget.uploadIndicatorColor ??
                  theme.onSurface.withValues(alpha: 0.8),
              strokeCap: StrokeCap.round,
              value: snapshot.data,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Time and status pill
// ─────────────────────────────────────────────────────────────────────────────

class _TimeAndStatus extends StatelessWidget {
  const _TimeAndStatus({
    required this.time,
    required this.showTime,
    required this.showStatus,
    this.status,
    this.backgroundColor,
    this.textStyle,
  });

  final DateTime? time;
  final MessageStatus? status;
  final bool showTime;
  final bool showStatus;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final timeFormat = context.watch<DateFormat>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 2,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTime && time != null)
            Text(timeFormat.format(time!.toLocal()), style: textStyle),
          if (showStatus && status != null)
            if (status == MessageStatus.sending)
              SizedBox(
                width: 6,
                height: 6,
                child: CircularProgressIndicator(
                  color: textStyle?.color,
                  strokeWidth: 2,
                ),
              )
            else
              Icon(
                getIconForStatus(status!),
                color: textStyle?.color,
                size: 12,
              ),
        ],
      ),
    );
  }
}
