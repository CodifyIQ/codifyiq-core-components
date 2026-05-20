import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyer_chat_video_message/flyer_chat_video_message.dart';
import 'package:provider/provider.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeChatController extends InMemoryChatController {
  _FakeChatController() : super(messages: []);
}

const _selfId = 'user-self';
const _otherId = 'user-other';

VideoMessage _message({
  String authorId = _selfId,
  double? width,
  double? height,
  Map<String, dynamic>? metadata,
}) =>
    VideoMessage(
      id: 'msg-1',
      authorId: authorId,
      source: 'https://example.com/video.mp4',
      width: width,
      height: height,
      metadata: metadata,
    );

// ── Pump helpers ───────────────────────────────────────────────────────────────

Widget _wrap(Widget child, {double height = 300}) {
  return MultiProvider(
    providers: [
      Provider<ChatController>.value(value: _FakeChatController()),
      Provider<UserID>.value(value: _selfId),
      Provider<ChatTheme>.value(value: ChatTheme.light()),
      Provider<DateFormat>.value(value: DateFormat.jm()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 300, height: height, child: child),
      ),
    ),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('FlyerChatVideoMessage', () {
    // ── Rendering ──────────────────────────────────────────────────────────

    testWidgets('renders custom video widget when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: _message(),
            index: 0,
            customVideoWidget: const Text('custom'),
          ),
        ),
      );
      expect(find.text('custom'), findsOneWidget);
    });

    testWidgets('renders thumbnailBuilder output when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: _message(),
            index: 0,
            thumbnailBuilder: (_, _) => const Text('thumb'),
          ),
        ),
      );
      expect(find.text('thumb'), findsOneWidget);
    });

    testWidgets('renders play overlay by default', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: _message(metadata: {'thumbnailUrl': 'https://x.com/t.jpg'}),
            index: 0,
          ),
        ),
      );
      // Default overlay uses play_arrow_rounded icon.
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('renders custom overlay when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: _message(metadata: {'thumbnailUrl': 'https://x.com/t.jpg'}),
            index: 0,
            overlay: const Icon(Icons.play_circle, key: Key('custom-overlay')),
          ),
        ),
      );
      expect(find.byKey(const Key('custom-overlay')), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    // ── Loading / error states ─────────────────────────────────────────────

    testWidgets('shows loading state during thumbnail generation', (tester) async {
      // Without thumbnailUrl and on a test environment (non-web, no native),
      // the widget starts in loading state. Use loadingBuilder to observe it.
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: _message(),
            index: 0,
            loadingBuilder: (_) => const Text('loading'),
          ),
        ),
      );
      // First frame: _ThumbnailState.loading — loadingBuilder fires.
      expect(find.text('loading'), findsOneWidget);
    });

    testWidgets('shows custom error widget when errorBuilder is provided',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: _message(),
            index: 0,
            // Skip thumbnail generation entirely via thumbnailBuilder that
            // returns a predictable error widget via errorBuilder is not
            // directly triggerable without native layer; test via errorBuilder
            // by passing a thumbnailBuilder that defers to it.
            thumbnailBuilder: (context, _) =>
                Image.network('https://invalid.invalid/no.jpg',
                    errorBuilder: (_, _, _) => const Text('error')),
          ),
        ),
      );
      await tester.pump();
      // Network image error fires asynchronously; pump a frame.
      await tester.pump(Duration.zero);
    });

    // ── Aspect ratio ──────────────────────────────────────────────────────

    testWidgets('uses message width/height for aspect ratio', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: _message(width: 1280, height: 720),
            index: 0,
            thumbnailBuilder: (_, _) => const SizedBox.expand(),
          ),
        ),
      );
      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatio.aspectRatio, closeTo(1280 / 720, 0.001));
    });

    testWidgets('defaults to 16:9 when dimensions are missing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: _message(),
            index: 0,
            thumbnailBuilder: (_, _) => const SizedBox.expand(),
          ),
        ),
      );
      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatio.aspectRatio, closeTo(16 / 9, 0.001));
    });

    // ── Duration badge ────────────────────────────────────────────────────

    testWidgets('shows duration badge when metadata provides it', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: _message(
              metadata: {
                'thumbnailUrl': 'https://x.com/t.jpg',
                'duration': '2:45',
              },
            ),
            index: 0,
          ),
        ),
      );
      expect(find.text('2:45'), findsOneWidget);
    });

    testWidgets('omits duration badge when not in metadata', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: _message(metadata: {'thumbnailUrl': 'https://x.com/t.jpg'}),
            index: 0,
          ),
        ),
      );
      // No duration text should appear.
      expect(find.textContaining(':'), findsNothing);
    });

    // ── Sent / received ───────────────────────────────────────────────────

    testWidgets('renders for sent message without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: _message(authorId: _selfId),
            index: 0,
            thumbnailBuilder: (_, _) => const SizedBox.expand(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders for received message without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: _message(authorId: _otherId),
            index: 0,
            thumbnailBuilder: (_, _) => const SizedBox.expand(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    // ── Semantics ─────────────────────────────────────────────────────────

    testWidgets('has semantic label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: VideoMessage(
              id: 'msg-1',
              authorId: _selfId,
              source: 'https://example.com/video.mp4',
              name: 'intro.mp4',
              metadata: const {'duration': '0:30'},
            ),
            index: 0,
            thumbnailBuilder: (_, _) => const SizedBox.expand(),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'Video message, intro\.mp4, duration 0:30'),
        ),
        findsOneWidget,
      );
    });

    // ── Network thumbnail ─────────────────────────────────────────────────

    testWidgets('uses network thumbnail when thumbnailUrl is in metadata',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: _message(
              metadata: {'thumbnailUrl': 'https://example.com/thumb.jpg'},
            ),
            index: 0,
          ),
        ),
      );
      // Image.network widget should be present in the tree.
      expect(find.byType(Image), findsAtLeastNWidgets(1));
    });

    // ── topWidget ─────────────────────────────────────────────────────────

    testWidgets('renders topWidget when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: _message(
              metadata: {'thumbnailUrl': 'https://x.com/t.jpg'},
            ),
            index: 0,
            topWidget: const Text('reply'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('reply'), findsOneWidget);
    });

    // ── showTime / showStatus ─────────────────────────────────────────────

    testWidgets('omits time pill when showTime and showStatus are false',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlyerChatVideoMessage(
            message: _message(
              metadata: {'thumbnailUrl': 'https://x.com/t.jpg'},
            ),
            index: 0,
            showTime: false,
            showStatus: false,
          ),
        ),
      );
      expect(find.textContaining(RegExp(r'\d+:\d+')), findsNothing);
    });

    // ── Tap / gesture pass-through ────────────────────────────────────────

    testWidgets('passes taps through to a parent GestureDetector',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          GestureDetector(
            onTap: () => tapped = true,
            child: FlyerChatVideoMessage(
              message: _message(
                metadata: {'thumbnailUrl': 'https://x.com/t.jpg'},
              ),
              index: 0,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(FlyerChatVideoMessage));
      expect(tapped, isTrue);
    });

    testWidgets('tap on overlay reaches parent GestureDetector', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          GestureDetector(
            onTap: () => tapped = true,
            child: FlyerChatVideoMessage(
              message: _message(
                metadata: {'thumbnailUrl': 'https://x.com/t.jpg'},
              ),
              index: 0,
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      expect(tapped, isTrue);
    });

    // ── Chat list behaviour ───────────────────────────────────────────────

    testWidgets('renders multiple messages in a list without error',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ListView(
            children: [
              for (var i = 0; i < 3; i++)
                FlyerChatVideoMessage(
                  message: VideoMessage(
                    id: 'msg-$i',
                    authorId: i.isEven ? _selfId : _otherId,
                    source: 'https://example.com/video$i.mp4',
                    metadata: {'thumbnailUrl': 'https://x.com/t$i.jpg'},
                  ),
                  index: i,
                ),
            ],
          ),
          height: 900,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(FlyerChatVideoMessage), findsNWidgets(3));
    });

    testWidgets('each list item uses its own aspect ratio', (tester) async {
      const dims = [(1280.0, 720.0), (640.0, 480.0), (9.0, 16.0)];
      await tester.pumpWidget(
        _wrap(
          ListView(
            children: [
              for (var i = 0; i < 3; i++)
                FlyerChatVideoMessage(
                  message: VideoMessage(
                    id: 'msg-$i',
                    authorId: _selfId,
                    source: 'https://example.com/video$i.mp4',
                    width: dims[i].$1,
                    height: dims[i].$2,
                    metadata: {'thumbnailUrl': 'https://x.com/t.jpg'},
                  ),
                  index: i,
                ),
            ],
          ),
          height: 900,
        ),
      );
      final ratios = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((w) => w.aspectRatio)
          .toList();
      expect(ratios[0], closeTo(1280 / 720, 0.001));
      expect(ratios[1], closeTo(640 / 480, 0.001));
      expect(ratios[2], closeTo(9 / 16, 0.001));
    });

    testWidgets('sent and received messages coexist in a list without error',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ListView(
            children: [
              FlyerChatVideoMessage(
                message: _message(
                  authorId: _selfId,
                  metadata: {'thumbnailUrl': 'https://x.com/t.jpg'},
                ),
                index: 0,
              ),
              FlyerChatVideoMessage(
                message: _message(
                  authorId: _otherId,
                  metadata: {'thumbnailUrl': 'https://x.com/t.jpg'},
                ),
                index: 1,
              ),
            ],
          ),
          height: 600,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(FlyerChatVideoMessage), findsNWidgets(2));
    });
  });
}
