import 'package:codifyiq_audio_message/codifyiq_audio_message.dart';
import 'package:flutter/foundation.dart';
import 'package:codifyiq_image_viewer/codifyiq_image_viewer.dart';
import 'package:codifyiq_pdf_viewer/codifyiq_pdf_viewer.dart';
import 'package:codifyiq_video_viewer/codifyiq_video_viewer.dart';
import 'package:cross_cache/cross_cache.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'attachment_source.dart';
import 'chat_attachment_action.dart';
import 'chat_attachment_labels.dart';
import 'chat_attachment_metadata.dart';
import 'chat_audio_attachment.dart';
import 'chat_file_attachment.dart';
import 'chat_image_attachment.dart';
import 'chat_video_attachment.dart';
import 'data_uri_image.dart';
import 'thumbhash_image.dart';

/// Called when the user chooses Share in a viewer opened from [message].
///
/// [sharePositionOrigin] is the Share button's screen rect; pass it to
/// `share_plus` so the iPad share sheet anchors to the button.
typedef ChatAttachmentShareCallback =
    void Function(Message message, Rect? sharePositionOrigin);

/// Called with the [message] an attachment action applies to.
typedef ChatAttachmentCallback = void Function(Message message);

/// Which images the image viewer pages through.
enum ChatImageGallery {
  /// Every image message in the conversation, oldest first, starting at the
  /// one tapped.
  conversation,

  /// Only the image tapped.
  message,
}

/// Plugs the CodifyIQ image, PDF, video and audio players into
/// `flutter_chat_ui`.
///
/// It supplies an `imageMessageBuilder`, a `fileMessageBuilder`, a
/// `videoMessageBuilder` and an `audioMessageBuilder` that draw
/// [ChatImageAttachment], [ChatFileAttachment], [ChatVideoAttachment] and
/// [ChatAudioAttachment] bubbles. Tapping one opens the matching viewer:
///
/// * images open `ImageViewerWidget`, with a Hero, over every image in the
///   conversation (see [imageGallery]);
/// * PDFs open `PdfViewerScreen`, and other files go to [onOpenFile];
/// * videos open `VideoViewerScreen`;
/// * audio plays in the bubble, through [audioController].
///
/// Bubbles take their colours, shape and text styles from the `ChatTheme`
/// that `Chat` provides, and show the message's time and status like
/// `flutter_chat_ui`'s own bubbles.
///
/// A message's `source` may be a network URL, a `blob:` URL on the web, or
/// a local file path or `file://` URI elsewhere. Images and videos may also
/// name a bundled asset (`assets/...`), and images may be `data:` URIs, as
/// with `flutter_chat_ui`'s own bubbles. Share and Download appear in the
/// viewers when [onShare] and [onDownload] are set, and receive the message
/// they belong to, as do your own [actions].
///
/// ```dart
/// final attachments = ChatAttachments(
///   headers: (message) => {'Authorization': 'Bearer $token'},
///   onShare: (message, origin) => share(message, origin),
/// );
///
/// Chat(
///   builders: attachments.apply(
///     Builders(textMessageBuilder: buildText),
///   ),
///   ...
/// );
/// ```
class ChatAttachments {
  /// Creates a [ChatAttachments].
  const ChatAttachments({
    this.headers,
    this.imageProvider,
    this.imageThumbnail,
    this.imageGallery = ChatImageGallery.conversation,
    this.videoThumbnail,
    this.videoDuration,
    this.onShare,
    this.onDownload,
    this.onOpenFile,
    this.actions = const [],
    this.openOnTap = true,
    this.audioController,
    this.showTime = true,
    this.showStatus = true,
    this.timeAndStatusPosition = TimeAndStatusPosition.end,
    this.topWidget,
    this.imageOverlay,
    this.imageErrorBuilder,
    this.fileIcon,
    this.maxWidth = 280,
    this.maxHeight,
    this.borderRadius,
    this.labels = const ChatAttachmentLabels(),
    this.useRootNavigator = true,
    this.routeBuilder,
  });

  /// HTTP headers for loading [message]'s network source, for example an
  /// `Authorization` header for private storage. Not used for local files,
  /// and ignored by the video player on the web.
  final Map<String, String>? Function(Message message)? headers;

  /// Builds the full image for an image message.
  ///
  /// Use it to plug in a provider of your own. By default, network sources
  /// load through the `CrossCache` that `Chat` provides, as
  /// `flutter_chat_ui`'s own image bubble loads them, so they are cached on
  /// disk and downloaded once for the bubble and the viewer. Outside a `Chat`
  /// they load with a [NetworkImage]. Either way they send [headers]. Assets,
  /// `data:` URIs and local files load from where they are.
  final ImageProvider Function(ImageMessage message)? imageProvider;

  /// The small version of an image message shown in its bubble, if any.
  ///
  /// The viewer shows it while the full image loads, so the full image is
  /// only downloaded when the bubble is tapped. By default it is loaded from
  /// the message's [ChatAttachmentMetadata.thumbnail]. Without a thumbnail,
  /// the bubble shows the full image, decoded no larger than the bubble.
  final ImageProvider? Function(ImageMessage message)? imageThumbnail;

  /// Which images the image viewer pages through.
  ///
  /// [ChatImageGallery.conversation] reads the conversation from the
  /// `ChatController` that `flutter_chat_ui`'s `Chat` provides, and falls back
  /// to the single image outside a `Chat`.
  final ChatImageGallery imageGallery;

  /// The poster image for a video message, if any. By default it is loaded
  /// from the message's [ChatAttachmentMetadata.thumbnail].
  final ImageProvider? Function(VideoMessage message)? videoThumbnail;

  /// The length of a video message, if known, shown on its tile. By default
  /// it is read from the message's [ChatAttachmentMetadata.durationMs].
  final Duration? Function(VideoMessage message)? videoDuration;

  /// Called when the user chooses Share in a viewer. If `null`, Share is
  /// hidden.
  final ChatAttachmentShareCallback? onShare;

  /// Called when the user chooses Download in a viewer. If `null`, Download
  /// is hidden.
  final ChatAttachmentCallback? onDownload;

  /// Called when the user taps a file that is not a PDF. If `null`, those
  /// files are not tappable.
  final ChatAttachmentCallback? onOpenFile;

  /// Your own actions in the viewers' overflow menus, after Share and
  /// Download.
  final List<ChatAttachmentAction> actions;

  /// Whether tapping an image, file or video bubble opens it.
  ///
  /// Set it to `false` to handle taps yourself with `Chat`'s `onMessageTap`,
  /// for example to select messages or retry failed ones, and open
  /// attachments with [openImage], [openPdf] and [openVideo]. Long presses
  /// and double taps reach `Chat` either way, and audio messages always
  /// play from their own buttons.
  final bool openOnTap;

  /// The audio controller the chat screen shares between audio messages, so
  /// that one plays at a time and keeps playing when its bubble scrolls out
  /// of view. Create it with the screen and dispose it with the screen.
  /// Without one, each audio bubble plays on its own and stops when it is
  /// disposed.
  final AudioMessageController? audioController;

  /// Whether bubbles show the time their message was sent.
  final bool showTime;

  /// Whether the current user's bubbles show their message's status.
  final bool showStatus;

  /// Where bubbles show the time and status, as on `flutter_chat_ui`'s text
  /// bubbles: on a line of their own at the start or end edge, or with
  /// [TimeAndStatusPosition.inline] beside the caption, or on files beside
  /// the type and size.
  final TimeAndStatusPosition timeAndStatusPosition;

  /// A widget shown at the top of [message]'s bubble, such as the author's
  /// name in a group chat or a preview of the message it replies to.
  final Widget? Function(Message message)? topWidget;

  /// Shown over images whose message has `hasOverlay` set, for example a
  /// blur over sensitive content.
  final Widget? imageOverlay;

  /// Builds what an image bubble shows when its image fails to load.
  /// Defaults to a broken image icon.
  final ImageErrorWidgetBuilder? imageErrorBuilder;

  /// The icon for a file message. When `null`, or when it returns `null`,
  /// PDFs get a PDF icon and other files a generic one.
  final IconData? Function(FileMessage message)? fileIcon;

  /// The widest an attachment bubble grows.
  final double maxWidth;

  /// The tallest an image or video grows in its bubble. Defaults to 4/3 of
  /// [maxWidth].
  final double? maxHeight;

  /// The bubbles' corner radius. Defaults to the `ChatTheme`'s shape.
  final BorderRadiusGeometry? borderRadius;

  /// Text the bubbles show or announce, for localisation.
  final ChatAttachmentLabels labels;

  /// Whether the viewers open on the root navigator, above any bottom
  /// navigation bar or nested navigator around the chat.
  final bool useRootNavigator;

  /// Builds the route a viewer opens in, for a different transition or a
  /// route of your own. Defaults to a full-screen-dialog [MaterialPageRoute].
  final Route<void> Function(WidgetBuilder builder)? routeBuilder;

  /// Returns [builders] with this adapter's image, file, video and audio
  /// message builders, keeping every other builder.
  ///
  /// To use only some of them, pass them to `Builders` yourself instead, for
  /// example `Builders(imageMessageBuilder: attachments.imageMessageBuilder)`.
  Builders apply([Builders builders = const Builders()]) => builders.copyWith(
    imageMessageBuilder: imageMessageBuilder,
    fileMessageBuilder: fileMessageBuilder,
    videoMessageBuilder: videoMessageBuilder,
    audioMessageBuilder: audioMessageBuilder,
  );

  /// Builds a [ChatImageAttachment] that opens the image viewer. Matches
  /// `flutter_chat_core`'s `ImageMessageBuilder`.
  Widget imageMessageBuilder(
    BuildContext context,
    ImageMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final thumbhash = message.thumbhash;
    final placeholder = thumbhash == null || thumbhash.isEmpty
        ? null
        : ThumbhashImage(thumbhash);
    return ChatImageAttachment(
      image: _thumbnailFor(context, message),
      placeholder: placeholder,
      isSentByMe: isSentByMe,
      width: message.width,
      height: message.height,
      caption: message.text,
      heroTag: _heroTag(message),
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      borderRadius: borderRadius,
      status: message.resolvedStatus,
      uploadProgress: _uploadProgress(context, message),
      time: message.resolvedTime,
      showTime: showTime,
      showStatus: showStatus,
      timeAndStatusPosition: timeAndStatusPosition,
      topWidget: topWidget?.call(message),
      overlay: message.hasOverlay ?? false ? imageOverlay : null,
      errorBuilder: imageErrorBuilder,
      labels: labels,
      onTap: openOnTap ? () => openImage(context, message) : null,
    );
  }

  /// Builds a [ChatFileAttachment] that opens PDFs in the PDF viewer and
  /// other files with [onOpenFile]. Matches `flutter_chat_core`'s
  /// `FileMessageBuilder`.
  Widget fileMessageBuilder(
    BuildContext context,
    FileMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final isPdfFile = isPdf(message.name, message.mimeType);
    final onOpenFile = this.onOpenFile;
    return ChatFileAttachment(
      name: message.name,
      size: message.size,
      mimeType: message.mimeType,
      icon: fileIcon?.call(message),
      isSentByMe: isSentByMe,
      maxWidth: maxWidth,
      borderRadius: borderRadius,
      status: message.resolvedStatus,
      uploadProgress: _uploadProgress(context, message),
      time: message.resolvedTime,
      showTime: showTime,
      showStatus: showStatus,
      timeAndStatusPosition: timeAndStatusPosition,
      topWidget: topWidget?.call(message),
      labels: labels,
      onTap: !openOnTap
          ? null
          : isPdfFile
          ? () => openPdf(context, message)
          : onOpenFile == null
          ? null
          : () => onOpenFile(message),
    );
  }

  /// Builds a [ChatVideoAttachment] that opens the video viewer. Matches
  /// `flutter_chat_core`'s `VideoMessageBuilder`.
  Widget videoMessageBuilder(
    BuildContext context,
    VideoMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final videoThumbnail = this.videoThumbnail;
    final videoDuration = this.videoDuration;
    final metadata = message.metadata;
    return ChatVideoAttachment(
      thumbnail: videoThumbnail != null
          ? videoThumbnail(message)
          : _metadataThumbnail(context, message),
      duration: videoDuration != null
          ? videoDuration(message)
          : switch (metadata?[ChatAttachmentMetadata.durationMs]) {
              final num ms => Duration(milliseconds: ms.toInt()),
              _ => null,
            },
      width: message.width,
      height: message.height,
      caption: message.text,
      isSentByMe: isSentByMe,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      borderRadius: borderRadius,
      status: message.resolvedStatus,
      uploadProgress: _uploadProgress(context, message),
      time: message.resolvedTime,
      showTime: showTime,
      showStatus: showStatus,
      timeAndStatusPosition: timeAndStatusPosition,
      topWidget: topWidget?.call(message),
      labels: labels,
      onTap: openOnTap ? () => openVideo(context, message) : null,
    );
  }

  /// Builds a [ChatAudioAttachment] that plays through [audioController].
  /// Matches `flutter_chat_core`'s `AudioMessageBuilder`.
  Widget audioMessageBuilder(
    BuildContext context,
    AudioMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    return ChatAudioAttachment(
      source: switch (AttachmentSource.parse(message.source)) {
        AssetAttachmentSource(:final name) => AudioMessageSource.asset(name),
        RemoteAttachmentSource(:final uri) => AudioMessageSource.uri(
          uri,
          headers: headers?.call(message),
        ),
        FileAttachmentSource(:final path) => AudioMessageSource.file(path),
      },
      id: message.id,
      controller: audioController,
      duration: message.duration,
      caption: message.text,
      isSentByMe: isSentByMe,
      maxWidth: maxWidth,
      borderRadius: borderRadius,
      status: message.resolvedStatus,
      uploadProgress: _uploadProgress(context, message),
      time: message.resolvedTime,
      showTime: showTime,
      showStatus: showStatus,
      timeAndStatusPosition: timeAndStatusPosition,
      topWidget: topWidget?.call(message),
      labels: labels,
    );
  }

  /// Opens the image viewer on [message], paging through [imageGallery].
  Future<void> openImage(BuildContext context, ImageMessage message) {
    final images = _galleryFor(context, message);
    final byId = {for (final image in images) image.id: image};
    final onShare = this.onShare;
    final onDownload = this.onDownload;
    // Built now, while the bubble's context is still mounted.
    final items = [
      for (final image in images)
        ImageViewerItem(
          provider: _imageFor(context, image),
          // What the bubble showed, so the page has it at once.
          placeholder: _thumbnailFor(context, image),
          id: image.id,
          caption: image.text,
          heroTag: _heroTag(image),
        ),
    ];
    return _push(
      context,
      (_) => ImageViewerWidget(
        items: items,
        initialIndex: images.indexWhere((image) => image.id == message.id),
        onShare: onShare == null
            ? null
            : (item, index, origin) => onShare(byId[item.id]!, origin),
        onDownload: onDownload == null
            ? null
            : (item, index) => onDownload(byId[item.id]!),
        actions: [
          for (final action in actions)
            ImageViewerAction(
              label: action.label,
              icon: action.icon,
              onSelected: (item, index) => action.onSelected(byId[item.id]!),
              isVisible: action.isVisible == null
                  ? null
                  : (item, index) => action.isVisible!(byId[item.id]!),
            ),
        ],
      ),
    );
  }

  /// Opens [message] in the PDF viewer.
  Future<void> openPdf(BuildContext context, FileMessage message) async {
    final onShare = this.onShare;
    final onDownload = this.onDownload;
    final PdfSource source;
    switch (AttachmentSource.parse(message.source)) {
      case AssetAttachmentSource(:final name):
        // The viewer reads no assets, so it is given the asset's bytes.
        try {
          final data = await DefaultAssetBundle.of(context).load(name);
          source = PdfSource.bytes(
            Uint8List.sublistView(data),
            sourceName: message.name,
          );
        } on Object catch (error, stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'codifyiq_chat_attachments',
              context: ErrorDescription('while loading the PDF asset $name'),
            ),
          );
          return;
        }
        if (!context.mounted) return;
      case RemoteAttachmentSource(:final uri):
        source = PdfSource.uri(uri, headers: headers?.call(message));
      case FileAttachmentSource(:final path):
        source = PdfSource.file(path);
    }
    return _push(
      context,
      (_) => PdfViewerScreen(
        source: source,
        title: message.name,
        onShare: onShare == null ? null : (origin) => onShare(message, origin),
        onDownload: onDownload == null ? null : () => onDownload(message),
        actions: [
          for (final action in _actionsFor(message))
            PdfViewerAction(
              label: action.label,
              icon: action.icon,
              onSelected: () => action.onSelected(message),
            ),
        ],
      ),
    );
  }

  /// Opens [message] in the video viewer.
  Future<void> openVideo(BuildContext context, VideoMessage message) {
    final onShare = this.onShare;
    final onDownload = this.onDownload;
    return _push(
      context,
      (_) => VideoViewerScreen(
        source: switch (AttachmentSource.parse(message.source)) {
          AssetAttachmentSource(:final name) => VideoSource.asset(name),
          RemoteAttachmentSource(:final uri) => VideoSource.uri(
            uri,
            headers: headers?.call(message),
          ),
          FileAttachmentSource(:final path) => VideoSource.file(path),
        },
        title: message.name,
        onShare: onShare == null ? null : (origin) => onShare(message, origin),
        onDownload: onDownload == null ? null : () => onDownload(message),
        actions: [
          for (final action in _actionsFor(message))
            VideoViewerAction(
              label: action.label,
              icon: action.icon,
              onSelected: () => action.onSelected(message),
            ),
        ],
      ),
    );
  }

  Iterable<ChatAttachmentAction> _actionsFor(Message message) =>
      actions.where((action) => action.isVisible?.call(message) ?? true);

  Future<void> _push(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context, rootNavigator: useRootNavigator).push(
        routeBuilder?.call(builder) ??
            MaterialPageRoute<void>(fullscreenDialog: true, builder: builder),
      );

  ImageProvider _imageFor(BuildContext context, ImageMessage message) {
    final imageProvider = this.imageProvider;
    return imageProvider != null
        ? imageProvider(message)
        : _load(context, message, message.source);
  }

  // The image's thumbnail, or else the full image decoded at bubble size.
  ImageProvider _thumbnailFor(BuildContext context, ImageMessage message) {
    final imageThumbnail = this.imageThumbnail;
    final thumbnail = imageThumbnail != null
        ? imageThumbnail(message)
        : _metadataThumbnail(context, message);
    return thumbnail ??
        ResizeImage.resizeIfNeeded(
          (maxWidth * MediaQuery.devicePixelRatioOf(context)).round(),
          null,
          _imageFor(context, message),
        );
  }

  ImageProvider? _metadataThumbnail(BuildContext context, Message message) =>
      switch (message.metadata?[ChatAttachmentMetadata.thumbnail]) {
        final String source => _load(context, message, source),
        _ => null,
      };

  // Reads sources the way flutter_chat_ui's own image bubble does, through
  // the CrossCache that Chat provides, so the bubble and the viewer share one
  // download, kept on disk.
  ImageProvider _load(BuildContext context, Message message, String source) {
    if (source.startsWith('data:')) return DataUriImage(source);
    return switch (AttachmentSource.parse(source)) {
      AssetAttachmentSource(:final name) => AssetImage(name),
      RemoteAttachmentSource(:final url) => switch (context
          .read<CrossCache?>()) {
        final cache? => CachedNetworkImage(
          url,
          cache,
          headers: headers?.call(message),
        ),
        null => NetworkImage(url, headers: headers?.call(message)),
      },
      FileAttachmentSource(:final path) => ImageViewerItem.file(path).provider,
    };
  }

  // The progress stream each sending message was given, per chat controller.
  // getUploadProgress opens a new stream whenever none is open, so asking
  // again after an upload completes would open one that is never closed.
  static final _progressStreams = Expando<Map<String, Stream<double>>>();

  // The upload's progress while [message] is sending, from a chat controller
  // that tracks it.
  Stream<double>? _uploadProgress(BuildContext context, Message message) {
    if (_chatController(context)
        case final ChatController chat &&
            final UploadProgressMixin controller) {
      final streams = _progressStreams[controller] ??= {};
      if (message.resolvedStatus == MessageStatus.sending) {
        if (streams[message.id] case final stream?) return stream;
        // Forgets the streams of messages the chat no longer holds, such as
        // ones deleted while sending.
        final ids = {for (final message in chat.messages) message.id};
        streams.removeWhere((id, _) => !ids.contains(id));
        return streams[message.id] = controller.getUploadProgress(message.id);
      }
      streams.remove(message.id);
    }
    return null;
  }

  /// The ids of the sending messages whose upload progress [controller] has
  /// handed out, for tests.
  @visibleForTesting
  static Iterable<String> debugUploadProgressIds(ChatController controller) =>
      _progressStreams[controller]?.keys ?? const [];

  static ChatController? _chatController(BuildContext context) =>
      context.read<ChatController?>();

  // The images to page through: the conversation's, when there is a chat
  // around [context] that still holds [message], otherwise just [message].
  List<ImageMessage> _galleryFor(BuildContext context, ImageMessage message) {
    final controller = _chatController(context);
    if (imageGallery == ChatImageGallery.conversation && controller != null) {
      final images = controller.messages
          .whereType<ImageMessage>()
          .where((image) => image.deletedAt == null)
          .toList();
      if (images.any((image) => image.id == message.id)) return images;
    }
    return [message];
  }

  static Object _heroTag(ImageMessage message) =>
      'codifyiq_chat_attachments:${message.id}';
}
