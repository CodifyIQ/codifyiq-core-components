import 'dart:async';
import 'dart:convert';

import 'package:codifyiq_chat_attachments/codifyiq_chat_attachments.dart';
import 'package:codifyiq_chat_attachments/src/data_uri_image.dart';
import 'package:codifyiq_image_viewer/codifyiq_image_viewer.dart';
import 'package:codifyiq_pdf_viewer/codifyiq_pdf_viewer.dart';
import 'package:codifyiq_video_viewer/codifyiq_video_viewer.dart';
import 'package:cross_cache/cross_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_player_platform.dart';
import 'fake_wakelock.dart';

// A 1x1 transparent PNG, so bubbles and viewer pages have an image to decode.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

ImageMessage _image(
  String id, {
  String? text,
  MessageStatus? status,
  Map<String, dynamic>? metadata,
}) =>
    Message.image(
          id: id,
          authorId: 'them',
          source: 'https://example.com/$id.png',
          text: text,
          width: 400,
          height: 300,
          status: status,
          metadata: metadata,
        )
        as ImageMessage;

const _pdf =
    Message.file(
          id: 'pdf',
          authorId: 'them',
          source: 'https://example.com/report.pdf',
          name: 'report.pdf',
          size: 1536,
          mimeType: 'application/pdf',
        )
        as FileMessage;

const _zip =
    Message.file(
          id: 'zip',
          authorId: 'them',
          source: 'https://example.com/photos.zip',
          name: 'photos.zip',
        )
        as FileMessage;

const _video =
    Message.video(
          id: 'video',
          authorId: 'them',
          source: 'https://example.com/clip.mp4',
          name: 'clip.mp4',
          text: 'Look at this',
          width: 1920,
          height: 1080,
        )
        as VideoMessage;

/// Builds [message] with [attachments], optionally inside a [ChatController]
/// holding [conversation] and a [CrossCache], the way `Chat` provides them.
Future<void> _pump(
  WidgetTester tester,
  ChatAttachments attachments,
  Message message, {
  List<Message>? conversation,
  CrossCache? cache,
  bool isSentByMe = false,
}) async {
  Widget bubble = Builder(
    builder: (context) => switch (message) {
      final ImageMessage m => attachments.imageMessageBuilder(
        context,
        m,
        0,
        isSentByMe: isSentByMe,
      ),
      final FileMessage m => attachments.fileMessageBuilder(
        context,
        m,
        0,
        isSentByMe: isSentByMe,
      ),
      final VideoMessage m => attachments.videoMessageBuilder(
        context,
        m,
        0,
        isSentByMe: isSentByMe,
      ),
      _ => throw UnsupportedError('$message'),
    },
  );
  if (conversation != null) {
    bubble = Provider<ChatController>.value(
      value: InMemoryChatController(messages: conversation),
      child: bubble,
    );
  }
  if (cache != null) {
    bubble = Provider<CrossCache>.value(value: cache, child: bubble);
  }
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: bubble)),
    ),
  );
}

ChatAttachments _attachments({
  ChatImageGallery imageGallery = ChatImageGallery.conversation,
  ChatAttachmentShareCallback? onShare,
  ChatAttachmentCallback? onDownload,
  ChatAttachmentCallback? onOpenFile,
}) => ChatAttachments(
  imageProvider: (_) => MemoryImage(_png),
  imageGallery: imageGallery,
  onShare: onShare,
  onDownload: onDownload,
  onOpenFile: onOpenFile,
);

// The URL and headers of a network image's provider.
(String, Map<String, String>?) _network(ImageProvider provider) =>
    switch (provider) {
      NetworkImage(:final url, :final headers) => (url, headers),
      _ => throw StateError('Unexpected provider $provider'),
    };

// The upload's ring, not the small sending indicator next to the time.
final _uploadRing = find.byWidgetPredicate(
  (widget) =>
      widget is CircularProgressIndicator && widget.semanticsLabel == 'Sending',
);

void main() {
  setUp(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    FakeWakelock.install();
  });

  group('apply', () {
    test('adds the attachment builders and keeps the others', () {
      Widget text(
        BuildContext context,
        TextMessage message,
        int index, {
        required bool isSentByMe,
        MessageGroupStatus? groupStatus,
      }) => const SizedBox();

      final builders = const ChatAttachments().apply(
        Builders(textMessageBuilder: text),
      );

      expect(builders.textMessageBuilder, same(text));
      expect(builders.imageMessageBuilder, isNotNull);
      expect(builders.fileMessageBuilder, isNotNull);
      expect(builders.videoMessageBuilder, isNotNull);
    });
  });

  group('image messages', () {
    testWidgets('shows the caption and sizes the image from the message', (
      tester,
    ) async {
      await _pump(tester, _attachments(), _image('a', text: 'Kitchen'));

      expect(find.text('Kitchen'), findsOneWidget);
      final ratio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(ratio.aspectRatio, 400 / 300);
    });

    testWidgets('uses the sent colours for the current user', (tester) async {
      await _pump(
        tester,
        _attachments(),
        _image('a', text: 'Kitchen'),
        isSentByMe: true,
      );

      final context = tester.element(find.text('Kitchen'));
      final colorScheme = Theme.of(context).colorScheme;
      expect(
        tester.widget<Text>(find.text('Kitchen')).style?.color,
        colorScheme.onPrimary,
      );
    });

    testWidgets('loads network sources with the message headers', (
      tester,
    ) async {
      final attachments = ChatAttachments(
        headers: (message) => {'Authorization': 'Bearer ${message.id}'},
      );
      await _pump(tester, attachments, _image('a'));

      // With no thumbnail, the full image is decoded at bubble size.
      final image = tester.widget<Image>(find.byType(Image));
      final resized = image.image as ResizeImage;
      expect(resized.width, (280 * tester.view.devicePixelRatio).round());
      final (url, headers) = _network(resized.imageProvider);
      expect(url, 'https://example.com/a.png');
      expect(headers, {'Authorization': 'Bearer a'});
    });

    testWidgets('loads network sources through the CrossCache Chat provides', (
      tester,
    ) async {
      final cache = CrossCache();
      addTearDown(cache.dispose);
      final attachments = ChatAttachments(
        headers: (message) => {'Authorization': 'Bearer ${message.id}'},
      );
      await _pump(tester, attachments, _image('a'), cache: cache);

      final image = tester.widget<Image>(find.byType(Image));
      final cached =
          (image.image as ResizeImage).imageProvider as CachedNetworkImage;
      expect(cached.url, 'https://example.com/a.png');
      expect(cached.crossCache, cache);
      expect(cached.headers, {'Authorization': 'Bearer a'});

      await tester.tap(find.byType(ChatImageAttachment));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final item = tester
          .widget<ImageViewerWidget>(find.byType(ImageViewerWidget))
          .items
          .single;
      // The bubble's download, shared with the viewer.
      expect(item.provider, cached);
    });

    testWidgets(
      'shows the metadata thumbnail and opens with it as placeholder',
      (tester) async {
        final attachments = ChatAttachments(
          headers: (message) => {'Authorization': 'Bearer ${message.id}'},
        );
        await _pump(
          tester,
          attachments,
          _image(
            'a',
            metadata: {
              ChatAttachmentMetadata.thumbnail:
                  'https://example.com/a-small.png',
            },
          ),
        );

        final thumbnail =
            tester.widget<Image>(find.byType(Image)).image as NetworkImage;
        expect(thumbnail.url, 'https://example.com/a-small.png');
        expect(thumbnail.headers, {'Authorization': 'Bearer a'});

        await tester.tap(find.byType(ChatImageAttachment));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final item = tester
            .widget<ImageViewerWidget>(find.byType(ImageViewerWidget))
            .items
            .single;
        expect(_network(item.provider).$1, 'https://example.com/a.png');
        expect(item.placeholder, thumbnail);
      },
    );

    testWidgets('imageThumbnail overrides the metadata thumbnail', (
      tester,
    ) async {
      final small = MemoryImage(_png);
      await _pump(
        tester,
        ChatAttachments(imageThumbnail: (_) => small),
        _image(
          'a',
          metadata: {ChatAttachmentMetadata.thumbnail: 'https://x.test/a.png'},
        ),
      );

      expect(tester.widget<Image>(find.byType(Image)).image, same(small));
    });

    testWidgets('shows upload progress while sending', (tester) async {
      final a = _image('a', status: MessageStatus.sending);
      final controller = InMemoryChatController(messages: [a]);
      await tester.pumpWidget(
        MaterialApp(
          home: Provider<ChatController>.value(
            value: controller,
            child: Builder(
              builder: (context) => _attachments().imageMessageBuilder(
                context,
                a,
                0,
                isSentByMe: true,
              ),
            ),
          ),
        ),
      );

      controller.updateUploadProgress('a', 0.4);
      await tester.pump();

      final indicator = tester.widget<CircularProgressIndicator>(_uploadRing);
      expect(indicator.value, 0.4);
    });

    testWidgets('forgets the upload of a message deleted while sending', (
      tester,
    ) async {
      final a = _image('a', status: MessageStatus.sending);
      final b = _image('b', status: MessageStatus.sending);
      final controller = InMemoryChatController(messages: [a]);
      Future<void> pumpBubble(ImageMessage message) => tester.pumpWidget(
        MaterialApp(
          home: Provider<ChatController>.value(
            value: controller,
            child: Builder(
              builder: (context) => _attachments().imageMessageBuilder(
                context,
                message,
                0,
                isSentByMe: true,
              ),
            ),
          ),
        ),
      );

      await pumpBubble(a);
      expect(ChatAttachments.debugUploadProgressIds(controller), ['a']);

      await controller.removeMessage(a);
      await controller.insertMessage(b);
      await pumpBubble(b);
      expect(ChatAttachments.debugUploadProgressIds(controller), ['b']);
    });

    testWidgets('keeps the ring full once the upload completes', (
      tester,
    ) async {
      final a = _image('a', status: MessageStatus.sending);
      final controller = InMemoryChatController(messages: [a]);
      Future<void> pumpBubble() => tester.pumpWidget(
        MaterialApp(
          home: Provider<ChatController>.value(
            value: controller,
            child: Builder(
              builder: (context) => _attachments().imageMessageBuilder(
                context,
                a,
                0,
                isSentByMe: true,
              ),
            ),
          ),
        ),
      );
      await pumpBubble();

      controller.updateUploadProgress('a', 1);
      await tester.pump();
      // Rebuilding while the message is still sending reuses the finished
      // stream instead of opening a new one.
      await pumpBubble();
      await tester.pump();
      // A new stream would pick this up; the finished one ignores it.
      controller.updateUploadProgress('a', 0.5);
      await tester.pump();
      await tester.pump();

      final indicator = tester.widget<CircularProgressIndicator>(_uploadRing);
      expect(indicator.value, 1);
    });

    testWidgets('spins while sending without upload progress', (tester) async {
      await _pump(
        tester,
        _attachments(),
        _image('a', status: MessageStatus.sending),
      );

      final indicator = tester.widget<CircularProgressIndicator>(_uploadRing);
      expect(indicator.value, isNull);
    });

    testWidgets('marks a message that failed to send', (tester) async {
      await _pump(
        tester,
        _attachments(),
        _image('a', status: MessageStatus.error),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(_uploadRing, findsNothing);
    });

    testWidgets('screen readers can open the image', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _attachments(), _image('a', text: ''));

      // An empty caption falls back to 'Image', and the semantics tap
      // only works when the node carries a tap action.
      expect(find.semantics.byLabel('Image'), findsOne);
      tester.semantics.tap(find.semantics.byLabel('Image'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ImageViewerWidget), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('opens the conversation gallery at the image tapped', (
      tester,
    ) async {
      final b = _image('b', text: 'Second');
      await _pump(
        tester,
        _attachments(),
        b,
        conversation: [
          _image('a'),
          const Message.text(id: 't', authorId: 'me', text: 'hi'),
          b,
          _image('c'),
        ],
      );

      await tester.tap(find.byType(ChatImageAttachment));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final viewer = tester.widget<ImageViewerWidget>(
        find.byType(ImageViewerWidget),
      );
      expect(viewer.items.map((item) => item.id), ['a', 'b', 'c']);
      expect(viewer.initialIndex, 1);
      expect(viewer.items[1].caption, 'Second');
    });

    testWidgets('opens only the image tapped with ChatImageGallery.message', (
      tester,
    ) async {
      final b = _image('b');
      await _pump(
        tester,
        _attachments(imageGallery: ChatImageGallery.message),
        b,
        conversation: [_image('a'), b],
      );

      await tester.tap(find.byType(ChatImageAttachment));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final viewer = tester.widget<ImageViewerWidget>(
        find.byType(ImageViewerWidget),
      );
      expect(viewer.items.map((item) => item.id), ['b']);
    });

    testWidgets('opens the single image outside a chat', (tester) async {
      await _pump(tester, _attachments(), _image('a'));

      await tester.tap(find.byType(ChatImageAttachment));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final viewer = tester.widget<ImageViewerWidget>(
        find.byType(ImageViewerWidget),
      );
      expect(viewer.items.map((item) => item.id), ['a']);
      expect(viewer.initialIndex, 0);
    });

    testWidgets('passes the message to Share and Download', (tester) async {
      final shared = <Message>[];
      final downloaded = <Message>[];
      final a = _image('a');
      await _pump(
        tester,
        _attachments(
          onShare: (message, origin) => shared.add(message),
          onDownload: downloaded.add,
        ),
        a,
      );

      await tester.tap(find.byType(ChatImageAttachment));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final viewer = tester.widget<ImageViewerWidget>(
        find.byType(ImageViewerWidget),
      );
      viewer.onShare!(viewer.items.single, 0, null);
      viewer.onDownload!(viewer.items.single, 0);

      expect(shared, [a]);
      expect(downloaded, [a]);
    });

    testWidgets('hides Share and Download without callbacks', (tester) async {
      await _pump(tester, _attachments(), _image('a'));

      await tester.tap(find.byType(ChatImageAttachment));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final viewer = tester.widget<ImageViewerWidget>(
        find.byType(ImageViewerWidget),
      );

      expect(viewer.onShare, isNull);
      expect(viewer.onDownload, isNull);
    });
  });

  group('file messages', () {
    testWidgets('shows the name, type and size', (tester) async {
      await _pump(tester, _attachments(), _pdf);

      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('PDF · 1.5 KB'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    });

    testWidgets('rounds sizes before picking the unit', (tester) async {
      for (final (size, label) in [
        (10239, 'PDF · 10 KB'),
        (1048575, 'PDF · 1.0 MB'),
        (1023, 'PDF · 1023 B'),
      ]) {
        await _pump(tester, _attachments(), _pdf.copyWith(size: size));
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('opens PDFs in the PDF viewer', (tester) async {
      final shared = <Message>[];
      await _pump(
        tester,
        _attachments(onShare: (message, origin) => shared.add(message)),
        _pdf,
      );

      await tester.tap(find.byType(ChatFileAttachment));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final screen = tester.widget<PdfViewerScreen>(
        find.byType(PdfViewerScreen),
      );
      expect(screen.title, 'report.pdf');
      expect(
        (screen.source as PdfUriSource).uri,
        Uri.parse('https://example.com/report.pdf'),
      );
      expect(screen.onDownload, isNull);
      screen.onShare!(null);
      expect(shared, [_pdf]);
    });

    testWidgets('hands other files to onOpenFile', (tester) async {
      final opened = <Message>[];
      await _pump(tester, _attachments(onOpenFile: opened.add), _zip);

      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
      expect(find.text('ZIP'), findsOneWidget);
      await tester.tap(find.byType(ChatFileAttachment));
      await tester.pumpAndSettle();

      expect(opened, [_zip]);
      expect(find.byType(PdfViewerScreen), findsNothing);
    });

    testWidgets('rings the icon while sending and marks a failure', (
      tester,
    ) async {
      await _pump(
        tester,
        _attachments(),
        _pdf.copyWith(status: MessageStatus.sending),
      );
      expect(_uploadRing, findsOneWidget);

      await _pump(
        tester,
        _attachments(),
        _pdf.copyWith(status: MessageStatus.error),
      );
      expect(_uploadRing, findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('leaves other files untappable without onOpenFile', (
      tester,
    ) async {
      await _pump(tester, _attachments(), _zip);

      final inkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(ChatFileAttachment),
          matching: find.byType(InkWell),
        ),
      );
      expect(inkWell.onTap, isNull);
    });
  });

  group('video messages', () {
    testWidgets('shows the poster, duration and caption', (tester) async {
      final attachments = ChatAttachments(
        videoThumbnail: (_) => MemoryImage(_png),
        videoDuration: (_) => const Duration(minutes: 1, seconds: 5),
      );
      await _pump(tester, attachments, _video);

      final tile = tester.widget<VideoThumbnailTile>(
        find.byType(VideoThumbnailTile),
      );
      expect(tile.thumbnail, isA<MemoryImage>());
      expect(tile.duration, const Duration(minutes: 1, seconds: 5));
      expect(tile.aspectRatio, 1920 / 1080);
      expect(find.text('Look at this'), findsOneWidget);
    });

    testWidgets('a portrait video fills the bubble width', (tester) async {
      await _pump(
        tester,
        const ChatAttachments(),
        _video.copyWith(width: 1080, height: 1920),
      );

      expect(
        tester.getSize(find.byType(VideoThumbnailTile)),
        const Size(280, 280 * 4 / 3),
      );
    });

    testWidgets('reads the poster and duration from the metadata', (
      tester,
    ) async {
      await _pump(
        tester,
        const ChatAttachments(),
        _video.copyWith(
          metadata: {
            ChatAttachmentMetadata.thumbnail: 'https://example.com/clip.jpg',
            ChatAttachmentMetadata.durationMs: 65000,
          },
        ),
      );

      final tile = tester.widget<VideoThumbnailTile>(
        find.byType(VideoThumbnailTile),
      );
      expect(
        (tile.thumbnail as NetworkImage).url,
        'https://example.com/clip.jpg',
      );
      expect(tile.duration, const Duration(minutes: 1, seconds: 5));
    });

    testWidgets('opens the video viewer with the message headers', (
      tester,
    ) async {
      final attachments = ChatAttachments(
        headers: (message) => {'Authorization': 'Bearer ${message.id}'},
      );
      await _pump(tester, attachments, _video);

      await tester.tap(find.byType(VideoThumbnailTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final screen = tester.widget<VideoViewerScreen>(
        find.byType(VideoViewerScreen),
      );
      expect(screen.title, 'clip.mp4');
      final source = screen.source as VideoUriSource;
      expect(source.uri, Uri.parse('https://example.com/clip.mp4'));
      expect(source.headers, {'Authorization': 'Bearer video'});
    });
  });

  group('sources', () {
    ImageProvider bubbleImage(WidgetTester tester) =>
        tester.widget<Image>(find.byType(Image)).image;

    testWidgets('reads data: thumbnails and asset images', (tester) async {
      final data = 'data:image/png;base64,${base64Encode(_png)}';
      await _pump(
        tester,
        const ChatAttachments(),
        _image('a', metadata: {ChatAttachmentMetadata.thumbnail: data}),
      );
      expect(bubbleImage(tester), DataUriImage(data));

      await _pump(
        tester,
        const ChatAttachments(),
        _image('a').copyWith(source: 'assets/a.png'),
      );
      final resized = bubbleImage(tester) as ResizeImage;
      expect((resized.imageProvider as AssetImage).assetName, 'assets/a.png');
    });

    testWidgets('decodes a data: image', (tester) async {
      final data = 'data:image/png;base64,${base64Encode(_png)}';
      final info = await tester.runAsync(() {
        final completer = Completer<ImageInfo>();
        DataUriImage(data)
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener((info, _) => completer.complete(info)),
            );
        return completer.future;
      });
      expect(info?.image.width, 1);
      // The browser decodes images outside the test's fake async zone.
    }, skip: kIsWeb);

    testWidgets('reads file:// URIs as paths', (tester) async {
      await _pump(
        tester,
        const ChatAttachments(),
        _image('a').copyWith(source: 'file:///tmp/a.png'),
      );
      final resized = bubbleImage(tester) as ResizeImage;
      expect((resized.imageProvider as FileImage).file.path, '/tmp/a.png');

      await _pump(
        tester,
        const ChatAttachments(),
        _pdf.copyWith(source: 'file:///tmp/report.pdf'),
      );
      await tester.tap(find.byType(ChatFileAttachment));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final screen = tester.widget<PdfViewerScreen>(
        find.byType(PdfViewerScreen),
      );
      expect((screen.source as PdfFileSource).path, '/tmp/report.pdf');
    }, skip: kIsWeb);

    testWidgets('plays asset videos', (tester) async {
      await _pump(
        tester,
        const ChatAttachments(),
        _video.copyWith(source: 'assets/clip.mp4'),
      );
      await tester.tap(find.byType(VideoThumbnailTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final screen = tester.widget<VideoViewerScreen>(
        find.byType(VideoViewerScreen),
      );
      expect((screen.source as VideoAssetSource).name, 'assets/clip.mp4');
    });

    testWidgets('opens asset PDFs from their bytes', (tester) async {
      final bytes = Uint8List.fromList(utf8.encode('%PDF-1.4'));
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: _BytesBundle({'assets/report.pdf': bytes}),
            child: Scaffold(
              body: Builder(
                builder: (context) =>
                    const ChatAttachments().fileMessageBuilder(
                      context,
                      _pdf.copyWith(source: 'assets/report.pdf'),
                      0,
                      isSentByMe: false,
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ChatFileAttachment));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final screen = tester.widget<PdfViewerScreen>(
        find.byType(PdfViewerScreen),
      );
      final source = screen.source as PdfBytesSource;
      expect(source.bytes, bytes);
      expect(source.sourceName, 'report.pdf');
    });

    testWidgets('reports a missing asset PDF', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: _BytesBundle({}),
            child: Scaffold(
              body: Builder(
                builder: (context) =>
                    const ChatAttachments().fileMessageBuilder(
                      context,
                      _pdf.copyWith(source: 'assets/missing.pdf'),
                      0,
                      isSentByMe: false,
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ChatFileAttachment));
      await tester.pump();

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          'No assets/missing.pdf',
        ),
      );
      expect(find.byType(PdfViewerScreen), findsNothing);
    });
  });
}

// An asset bundle holding [assets].
class _BytesBundle extends CachingAssetBundle {
  _BytesBundle(this.assets);

  final Map<String, Uint8List> assets;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(assets[key] ?? (throw FlutterError('No $key')));
}
