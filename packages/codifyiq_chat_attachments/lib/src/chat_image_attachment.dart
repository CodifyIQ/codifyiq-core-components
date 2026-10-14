import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:material_ui/material_ui.dart';

import 'chat_attachment_labels.dart';
import 'chat_style.dart';
import 'media_bubble.dart';
import 'upload_overlay.dart';

/// An image message bubble: the picture, sized from its known dimensions,
/// with an optional caption and the message's time and status below it.
///
/// [ChatAttachments] builds one for every image message. Use it directly when
/// you write your own `imageMessageBuilder`.
class ChatImageAttachment extends StatefulWidget {
  /// Creates a [ChatImageAttachment].
  ///
  /// [image] is the picture to show and [onTap] opens it.
  const ChatImageAttachment({
    super.key,
    required this.image,
    required this.isSentByMe,
    this.placeholder,
    this.width,
    this.height,
    this.caption,
    this.heroTag,
    this.onTap,
    this.maxWidth = 280,
    this.maxHeight,
    this.borderRadius,
    this.status,
    this.uploadProgress,
    this.time,
    this.showTime = true,
    this.showStatus = true,
    this.timeAndStatusPosition = TimeAndStatusPosition.end,
    this.topWidget,
    this.overlay,
    this.errorBuilder,
    this.labels = const ChatAttachmentLabels(),
  });

  /// The picture to show.
  final ImageProvider image;

  /// Shown until [image] has loaded, for example a blurred ThumbHash.
  /// Without one, the bubble shows a plain background.
  final ImageProvider? placeholder;

  /// Whether the current user sent the message, which picks the caption's
  /// bubble colours and whether the status is shown.
  final bool isSentByMe;

  /// The image's width in pixels, if known. With [height] it sets the
  /// bubble's shape before the image loads, so the chat does not jump.
  /// Without them, the bubble takes the image's shape once it loads.
  final double? width;

  /// The image's height in pixels, if known.
  final double? height;

  /// Text shown below the image.
  final String? caption;

  /// Tag for a [Hero] into the viewer opened by [onTap].
  final Object? heroTag;

  /// Called when the image is tapped. If `null`, the bubble leaves taps to
  /// the widgets around it, such as `Chat`'s `onMessageTap`.
  final VoidCallback? onTap;

  /// The widest the bubble grows.
  final double maxWidth;

  /// The tallest the image grows. Defaults to 4/3 of [maxWidth].
  final double? maxHeight;

  /// The bubble's corner radius. Defaults to the `ChatTheme`'s shape.
  final BorderRadiusGeometry? borderRadius;

  /// The message's status. While it is [MessageStatus.sending] the bubble
  /// is dimmed with a progress indicator, and [MessageStatus.error] marks it
  /// as not sent.
  final MessageStatus? status;

  /// The upload's progress from 0 to 1 while [status] is
  /// [MessageStatus.sending]. Without it the indicator spins.
  final Stream<double>? uploadProgress;

  /// When the message was sent, shown below the image.
  final DateTime? time;

  /// Whether [time] is shown.
  final bool showTime;

  /// Whether [status] is shown next to the time, for the current user's
  /// messages.
  final bool showStatus;

  /// Where the time and status sit below the image: on a line of their own
  /// at the start or end edge, or with [TimeAndStatusPosition.inline] beside
  /// the caption.
  final TimeAndStatusPosition timeAndStatusPosition;

  /// A widget above the image, such as the author's name.
  final Widget? topWidget;

  /// Shown over the image, for example a blur over sensitive content.
  final Widget? overlay;

  /// Builds what is shown when the image fails to load. Defaults to a broken
  /// image icon.
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Text the bubble announces.
  final ChatAttachmentLabels labels;

  @override
  State<ChatImageAttachment> createState() => _ChatImageAttachmentState();
}

class _ChatImageAttachmentState extends State<ChatImageAttachment> {
  // The image's shape, measured once it loads when the message has none.
  double? _measuredAspectRatio;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  // Whether a picture has been shown, so a new image fades in only the first
  // time and later replaces the old one in place.
  bool _hasShownPicture = false;

  bool get _hasSize => (widget.width ?? 0) > 0 && (widget.height ?? 0) > 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_measuredAspectRatio == null) _measure();
  }

  @override
  void didUpdateWidget(ChatImageAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keeps the old shape until the new image gives its own, so the chat does
    // not jump when a sent photo's local file is swapped for its URL.
    if (oldWidget.image != widget.image) _measure();
  }

  void _measure() {
    _stopMeasuring();
    if (_hasSize) return;
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      final aspectRatio = info.image.width / info.image.height;
      info.dispose();
      _stopMeasuring();
      if (mounted) setState(() => _measuredAspectRatio = aspectRatio);
    }, onError: (_, _) => _stopMeasuring());
    // Set before listening, as a cached image calls the listener at once.
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _stopMeasuring() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stopMeasuring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = chatThemeOf(context).colors;
    final aspectRatio = _hasSize
        ? widget.width! / widget.height!
        : _measuredAspectRatio ?? 4 / 3;
    final placeholder = widget.placeholder;
    final overlay = widget.overlay;
    final onTap = widget.onTap;

    Widget picture = Image(
      image: widget.image,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null || wasSynchronouslyLoaded) _hasShownPicture = true;
        return AnimatedOpacity(
          opacity: _hasShownPicture ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder:
          widget.errorBuilder ??
          (context, error, stackTrace) => ColoredBox(
            color: colors.surfaceContainerHigh,
            child: Icon(
              Icons.broken_image_outlined,
              color: colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
    );
    if (widget.heroTag case final tag?) {
      picture = Hero(tag: tag, child: picture);
    }

    final text = widget.caption;
    return MediaBubble(
      aspectRatio: aspectRatio,
      isSentByMe: widget.isSentByMe,
      maxWidth: widget.maxWidth,
      maxHeight: widget.maxHeight,
      borderRadius: widget.borderRadius,
      caption: text,
      topWidget: widget.topWidget,
      time: widget.time,
      status: widget.status,
      showTime: widget.showTime,
      showStatus: widget.showStatus,
      timeAndStatusPosition: widget.timeAndStatusPosition,
      media: Stack(
        fit: StackFit.expand,
        children: [
          // The InkWell's tap is excluded with the rest, so it is given again.
          Semantics(
            image: true,
            button: onTap != null,
            label: text == null || text.isEmpty ? widget.labels.image : text,
            onTap: onTap,
            excludeSemantics: true,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (placeholder != null)
                  Image(
                    image: placeholder,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        ColoredBox(color: colors.surfaceContainerHigh),
                  )
                else
                  ColoredBox(color: colors.surfaceContainerHigh),
                picture,
                ?overlay,
                // Only tappable with onTap, so Chat's own gestures get the
                // tap otherwise.
                if (onTap != null)
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(onTap: onTap),
                  ),
              ],
            ),
          ),
          // Outside the excluded semantics, so sending and failure are
          // announced. It ignores taps, so they reach the InkWell below.
          UploadOverlay(
            status: widget.status,
            progress: widget.uploadProgress,
            labels: widget.labels,
          ),
        ],
      ),
    );
  }
}
