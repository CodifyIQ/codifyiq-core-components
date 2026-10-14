import 'dart:async';
import 'dart:convert';

import 'package:codifyiq_audio_message/codifyiq_audio_message.dart';
import 'package:codifyiq_chat_attachments/codifyiq_chat_attachments.dart';
import 'package:codifyiq_chat_attachments/src/thumbhash_image.dart';
import 'package:codifyiq_image_viewer/codifyiq_image_viewer.dart';
import 'package:codifyiq_pdf_viewer/codifyiq_pdf_viewer.dart';
import 'package:codifyiq_video_viewer/codifyiq_video_viewer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:thumbhash/thumbhash.dart' as thumbhash;
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_player_platform.dart';
import 'fake_wakelock.dart';

// A 1x1 transparent PNG, so bubbles and viewer pages have an image to decode.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

final _sentAt = DateTime(2026, 10, 15, 9, 41);

ImageMessage _image({
  double? width = 400,
  double? height = 300,
  String? thumbhash,
  bool? hasOverlay,
  String authorId = 'me',
}) =>
    Message.image(
          id: 'image',
          authorId: authorId,
          source: 'https://example.com/a.png',
          width: width,
          height: height,
          thumbhash: thumbhash,
          hasOverlay: hasOverlay,
          createdAt: _sentAt,
          sentAt: _sentAt,
        )
        as ImageMessage;

final _pdf =
    Message.file(
          id: 'pdf',
          authorId: 'me',
          source: 'https://example.com/report.pdf',
          name: 'report.pdf',
          size: 1536,
          mimeType: 'application/pdf',
          createdAt: _sentAt,
          sentAt: _sentAt,
        )
        as FileMessage;

final _video =
    Message.video(
          id: 'video',
          authorId: 'me',
          source: 'https://example.com/clip.mp4',
          name: 'clip.mp4',
          width: 1920,
          height: 1080,
          createdAt: _sentAt,
        )
        as VideoMessage;

final _audio =
    Message.audio(
          id: 'audio',
          authorId: 'them',
          source: 'https://example.com/note.m4a',
          duration: const Duration(seconds: 42),
          text: 'Listen to this',
          createdAt: _sentAt,
        )
        as AudioMessage;

/// Builds [message] the way `Chat` does: wrapped in its gesture detector, with
/// its theme, time format and controller provided. Gestures `Chat` receives
/// are added to [chatEvents].
Future<void> _pumpInChat(
  WidgetTester tester,
  ChatAttachments attachments,
  Message message, {
  List<String>? chatEvents,
  ChatTheme? theme,
}) async {
  final isSentByMe = message.authorId == 'me';
  // A fresh app, so a viewer opened earlier in the test is gone.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MultiProvider(
          providers: [
            Provider<ChatTheme>.value(
              value: theme ?? ChatTheme.fromThemeData(Theme.of(context)),
            ),
            Provider<DateFormat>.value(value: DateFormat('HH:mm')),
            Provider<ChatController>.value(
              value: InMemoryChatController(messages: [message]),
            ),
          ],
          child: Scaffold(
            body: Center(
              child: GestureDetector(
                onTapUp: (_) => chatEvents?.add('tap'),
                onDoubleTap: () => chatEvents?.add('double tap'),
                onLongPressStart: (_) => chatEvents?.add('long press'),
                child: Builder(
                  builder: (context) => attachments.apply().let(
                    (builders) => switch (message) {
                      final ImageMessage m => builders.imageMessageBuilder!(
                        context,
                        m,
                        0,
                        isSentByMe: isSentByMe,
                      ),
                      final FileMessage m => builders.fileMessageBuilder!(
                        context,
                        m,
                        0,
                        isSentByMe: isSentByMe,
                      ),
                      final VideoMessage m => builders.videoMessageBuilder!(
                        context,
                        m,
                        0,
                        isSentByMe: isSentByMe,
                      ),
                      final AudioMessage m => builders.audioMessageBuilder!(
                        context,
                        m,
                        0,
                        isSentByMe: isSentByMe,
                      ),
                      _ => throw UnsupportedError('$message'),
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

Future<void> _settleViewer(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

ChatAttachments _attachments({
  bool openOnTap = true,
  List<ChatAttachmentAction> actions = const [],
  Widget? Function(Message message)? topWidget,
  bool showTime = true,
  Widget? imageOverlay,
  IconData? Function(FileMessage message)? fileIcon,
  ChatAttachmentLabels labels = const ChatAttachmentLabels(),
  Route<void> Function(WidgetBuilder builder)? routeBuilder,
  AudioMessageController? audioController,
  double? maxHeight,
}) => ChatAttachments(
  imageProvider: (_) => MemoryImage(_png),
  openOnTap: openOnTap,
  actions: actions,
  topWidget: topWidget,
  showTime: showTime,
  imageOverlay: imageOverlay,
  fileIcon: fileIcon,
  labels: labels,
  routeBuilder: routeBuilder,
  audioController: audioController,
  maxHeight: maxHeight,
);

class _FakeAudioBackend implements AudioPlayerBackend {
  final sources = <AudioMessageSource>[];
  final _state = StreamController<AudioBackendState>.broadcast(sync: true);

  @override
  Stream<AudioBackendState> get stateStream => _state.stream;

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Stream<Duration?> get durationStream => const Stream.empty();

  @override
  Future<void> setSource(AudioMessageSource source) async =>
      sources.add(source);

  @override
  Future<void> play() async => _state.add(
    const AudioBackendState(
      processingState: AudioBackendProcessingState.ready,
      isPlaying: true,
    ),
  );

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

void main() {
  setUp(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    FakeWakelock.install();
  });

  group('gestures inside Chat', () {
    testWidgets('long press and double tap reach Chat; a tap opens the image', (
      tester,
    ) async {
      final events = <String>[];
      await _pumpInChat(tester, _attachments(), _image(), chatEvents: events);
      final bubble = find.byType(ChatImageAttachment);

      await tester.longPress(bubble);
      await tester.pump(const Duration(seconds: 1));
      final center = tester.getCenter(bubble);
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pump(const Duration(seconds: 1));
      expect(events, ['long press', 'double tap']);
      expect(find.byType(ImageViewerWidget), findsNothing);

      await tester.tap(bubble);
      // Chat waits out a possible double tap before the tap lands.
      await tester.pump(const Duration(milliseconds: 400));
      await _settleViewer(tester);
      expect(find.byType(ImageViewerWidget), findsOneWidget);
      expect(events, ['long press', 'double tap']);
    });

    for (final message in [_image(), _pdf, _video]) {
      testWidgets(
        'with openOnTap false, Chat gets the tap on a ${message.runtimeType}',
        (tester) async {
          final events = <String>[];
          await _pumpInChat(
            tester,
            _attachments(openOnTap: false),
            message,
            chatEvents: events,
          );

          await tester.tap(find.byType(Center).last);
          await tester.pump(const Duration(milliseconds: 400));
          await _settleViewer(tester);

          expect(events, ['tap']);
          expect(find.byType(ImageViewerWidget), findsNothing);
          expect(find.byType(PdfViewerScreen), findsNothing);
          expect(find.byType(VideoViewerScreen), findsNothing);
        },
      );
    }
  });

  group('ChatTheme', () {
    testWidgets('bubbles take the colours and shape of the ChatTheme', (
      tester,
    ) async {
      late ChatTheme theme;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            final base = ChatTheme.fromThemeData(ThemeData());
            theme = base.copyWith(
              colors: base.colors.copyWith(
                primary: Colors.deepOrange,
                onPrimary: Colors.yellow,
              ),
              shape: const BorderRadius.all(Radius.circular(3)),
            );
            return const SizedBox();
          },
        ),
      );
      await _pumpInChat(tester, _attachments(), _pdf, theme: theme);

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(ChatFileAttachment),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, Colors.deepOrange);
      expect(material.borderRadius, const BorderRadius.all(Radius.circular(3)));
      expect(
        tester.widget<Text>(find.text('report.pdf')).style?.color,
        Colors.yellow,
      );
    });
  });

  group('time and status', () {
    testWidgets('shows the time and, on sent messages, the status', (
      tester,
    ) async {
      await _pumpInChat(tester, _attachments(), _pdf);
      // With a hidden copy that reserves the time's line.
      expect(find.text('09:41'), findsNWidgets(2));
      expect(
        find.byIcon(getIconForStatus(MessageStatus.sent)),
        findsNWidgets(2),
      );

      await _pumpInChat(tester, _attachments(), _image());
      expect(find.text('09:41'), findsOneWidget);

      await _pumpInChat(tester, _attachments(), _image(authorId: 'them'));
      expect(find.text('09:41'), findsOneWidget);
      expect(find.byIcon(getIconForStatus(MessageStatus.sent)), findsNothing);
    });

    testWidgets('showTime false leaves the time out', (tester) async {
      await _pumpInChat(tester, _attachments(showTime: false), _video);
      expect(find.text('09:41'), findsNothing);
    });
  });

  testWidgets('topWidget is shown above the attachment', (tester) async {
    for (final message in [_image(), _pdf, _video, _audio]) {
      await _pumpInChat(
        tester,
        _attachments(
          topWidget: (message) => Text('from ${message.authorId}'),
          audioController: AudioMessageController(backend: _FakeAudioBackend()),
        ),
        message,
      );
      expect(find.text('from ${message.authorId}'), findsOneWidget);
    }
  });

  group('images', () {
    // So each test sees its image load, not one an earlier test decoded.
    setUp(imageCache.clear);

    testWidgets('a ThumbHash is the placeholder and gives the shape', (
      tester,
    ) async {
      final rgba = Uint8List(8 * 4 * 4)..fillRange(0, 8 * 4 * 4, 200);
      final hash = base64.encode(thumbhash.rgbaToThumbHash(8, 4, rgba));
      await _pumpInChat(
        tester,
        _attachments(),
        _image(width: null, height: null, thumbhash: hash),
      );

      final placeholder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image == ThumbhashImage(hash),
      );
      expect(placeholder, findsOneWidget);
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        // ThumbHash keeps the shape only roughly: 8x4 comes back as 5x3.
        greaterThan(1.5),
      );
    });

    testWidgets('an image without a size takes its shape once it loads', (
      tester,
    ) async {
      await _pumpInChat(
        tester,
        _attachments(),
        _image(width: null, height: null),
      );

      await tester.runAsync(
        () => precacheImage(
          MemoryImage(_png),
          tester.element(find.byType(ChatImageAttachment)),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        1,
      );
      // The browser decodes images outside the test's fake async zone.
    }, skip: kIsWeb);

    testWidgets('an image without a size moves from its ThumbHash shape to '
        'its own once it loads', (tester) async {
      final rgba = Uint8List(8 * 4 * 4)..fillRange(0, 8 * 4 * 4, 200);
      final hash = base64.encode(thumbhash.rgbaToThumbHash(8, 4, rgba));
      await _pumpInChat(
        tester,
        _attachments(),
        _image(width: null, height: null, thumbhash: hash),
      );
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        greaterThan(1.5),
      );

      await tester.runAsync(
        () => precacheImage(
          MemoryImage(_png),
          tester.element(find.byType(ChatImageAttachment)),
        ),
      );
      await tester.pump();
      // The 1x1 image's own shape, not the ThumbHash's.
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        1,
      );
      // The browser decodes images outside the test's fake async zone.
    }, skip: kIsWeb);

    testWidgets('shows imageOverlay only when the message asks for it', (
      tester,
    ) async {
      final attachments = _attachments(imageOverlay: const Text('Sensitive'));
      await _pumpInChat(tester, attachments, _image(hasOverlay: true));
      expect(find.text('Sensitive'), findsOneWidget);

      await _pumpInChat(tester, attachments, _image());
      expect(find.text('Sensitive'), findsNothing);
    });

    testWidgets('maxHeight caps the image', (tester) async {
      await _pumpInChat(
        tester,
        _attachments(maxHeight: 100),
        _image(width: 300, height: 400),
      );
      expect(tester.getSize(find.byType(AspectRatio)).height, 100);
    });

    testWidgets('labels name an image without a caption', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpInChat(
        tester,
        _attachments(labels: const ChatAttachmentLabels(image: 'Bild')),
        _image(),
      );
      expect(find.semantics.byLabel('Bild'), findsOne);
      semantics.dispose();
    });
  });

  testWidgets('fileIcon picks the icon', (tester) async {
    await _pumpInChat(
      tester,
      _attachments(fileIcon: (_) => Icons.description_outlined),
      _pdf,
    );
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
  });

  group('viewers', () {
    testWidgets('actions reach every viewer with the message', (tester) async {
      final chosen = <String>[];
      final actions = [
        ChatAttachmentAction(
          label: 'Forward',
          icon: Icons.forward,
          onSelected: (message) => chosen.add('forward ${message.id}'),
        ),
        ChatAttachmentAction(
          label: 'Open in browser',
          icon: Icons.open_in_browser,
          onSelected: (message) => chosen.add('open ${message.id}'),
          isVisible: (message) => message is FileMessage,
        ),
      ];

      await _pumpInChat(tester, _attachments(actions: actions), _image());
      await tester.tap(find.byType(ChatImageAttachment));
      await tester.pump(const Duration(milliseconds: 400));
      await _settleViewer(tester);
      final image = tester.widget<ImageViewerWidget>(
        find.byType(ImageViewerWidget),
      );
      final item = image.items.single;
      for (final action in image.actions) {
        if (action.isVisible?.call(item, 0) ?? true) {
          action.onSelected(item, 0);
        }
      }

      await _pumpInChat(tester, _attachments(actions: actions), _pdf);
      await tester.tap(find.byType(ChatFileAttachment));
      await tester.pump(const Duration(milliseconds: 400));
      await _settleViewer(tester);
      for (final action
          in tester
              .widget<PdfViewerScreen>(find.byType(PdfViewerScreen))
              .actions) {
        action.onSelected();
      }

      expect(chosen, ['forward image', 'forward pdf', 'open pdf']);
    });

    testWidgets('routeBuilder builds the viewer route', (tester) async {
      var routes = 0;
      await _pumpInChat(
        tester,
        _attachments(
          routeBuilder: (builder) {
            routes++;
            return PageRouteBuilder<void>(
              pageBuilder: (context, _, _) => builder(context),
            );
          },
        ),
        _video,
      );
      await tester.tap(find.byType(VideoThumbnailTile));
      await tester.pump(const Duration(milliseconds: 400));
      await _settleViewer(tester);

      expect(routes, 1);
      expect(find.byType(VideoViewerScreen), findsOneWidget);
    });
  });

  group('audio messages', () {
    testWidgets('apply adds the audio builder', (tester) async {
      expect(const ChatAttachments().apply().audioMessageBuilder, isNotNull);
    });

    testWidgets('plays through the shared controller with the message '
        'headers, showing the duration and caption', (tester) async {
      final backend = _FakeAudioBackend();
      final controller = AudioMessageController(backend: backend);
      addTearDown(controller.dispose);
      await _pumpInChat(
        tester,
        ChatAttachments(
          audioController: controller,
          headers: (message) => {'Authorization': 'Bearer ${message.id}'},
        ),
        _audio,
      );

      expect(find.text('00:00 / 00:42'), findsOneWidget);
      expect(find.text('Listen to this'), findsOneWidget);

      await tester.tap(find.byTooltip('Play'));
      // Chat waits out a possible double tap before the tap lands.
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.currentId, 'audio');
      expect(backend.sources, [
        AudioMessageSource.uri(
          Uri.parse('https://example.com/note.m4a'),
          headers: const {'Authorization': 'Bearer audio'},
        ),
      ]);
    });

    testWidgets('reads assets and local files', (tester) async {
      final backend = _FakeAudioBackend();
      final controller = AudioMessageController(backend: backend);
      addTearDown(controller.dispose);
      for (final source in ['assets/note.m4a', 'file:///tmp/note.m4a']) {
        await _pumpInChat(
          tester,
          ChatAttachments(audioController: controller),
          _audio.copyWith(id: source, source: source),
        );
        await tester.tap(find.byTooltip('Play'));
        // Chat waits out a possible double tap before the tap lands.
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(backend.sources, [
        const AudioMessageSource.asset('assets/note.m4a'),
        const AudioMessageSource.file('/tmp/note.m4a'),
      ]);
      // There are no local files on the web.
    }, skip: kIsWeb);

    testWidgets('marks a failed voice note once, whether or not the status '
        'is shown', (tester) async {
      final controller = AudioMessageController(backend: _FakeAudioBackend());
      addTearDown(controller.dispose);
      final failed = _audio.copyWith(
        authorId: 'me',
        status: MessageStatus.error,
      );
      for (final showStatus in [false, true]) {
        await _pumpInChat(
          tester,
          ChatAttachments(audioController: controller, showStatus: showStatus),
          failed,
        );
        expect(
          find.byIcon(Icons.error_outline),
          findsOneWidget,
          reason: 'showStatus: $showStatus',
        );
      }

      await _pumpInChat(
        tester,
        ChatAttachments(audioController: controller, showStatus: false),
        _audio,
      );
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });
}
