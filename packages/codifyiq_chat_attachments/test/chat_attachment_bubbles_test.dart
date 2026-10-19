import 'dart:async';
import 'dart:ui' as ui;

import 'package:codifyiq_chat_attachments/codifyiq_chat_attachments.dart';
import 'package:codifyiq_chat_attachments/src/thumbhash_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_player_platform.dart';

/// An image already in the cache, which calls its listeners as soon as they
/// are added, and records which listeners are still attached.
class _CachedImage extends ImageProvider<_CachedImage> {
  _CachedImage(ui.Image? image)
    : completer = _TrackingCompleter(
        image == null
            ? Completer<ImageInfo>().future
            : SynchronousFuture(ImageInfo(image: image)),
      );

  final _TrackingCompleter completer;

  @override
  Future<_CachedImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_CachedImage key, ImageDecoderCallback _) =>
      completer;
}

class _TrackingCompleter extends OneFrameImageStreamCompleter {
  _TrackingCompleter(super.image);

  final listeners = <ImageStreamListener>{};

  @override
  void addListener(ImageStreamListener listener) {
    listeners.add(listener);
    super.addListener(listener);
  }

  @override
  void removeListener(ImageStreamListener listener) {
    listeners.remove(listener);
    super.removeListener(listener);
  }
}

final _sentAt = DateTime(2026, 10, 15, 9, 41);

Future<void> _pump(WidgetTester tester, Widget bubble) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: bubble)),
  ),
);

void main() {
  group('image', () {
    testWidgets('measuring a cached image lets go of its listener and frame', (
      tester,
    ) async {
      final image = (await tester.runAsync(
        () => createTestImage(width: 2, height: 1),
      ))!;
      // How many handles and listeners the bubble holds when it need not
      // measure.
      final sized = _CachedImage(image);
      await _pump(
        tester,
        ChatImageAttachment(
          image: sized,
          isSentByMe: true,
          width: 2,
          height: 1,
        ),
      );
      final handles = image.debugGetOpenHandleStackTraces()!.length;
      await tester.pumpWidget(const SizedBox());

      final unsized = _CachedImage(image);
      await _pump(
        tester,
        ChatImageAttachment(image: unsized, isSentByMe: true),
      );

      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        2,
      );
      expect(image.debugGetOpenHandleStackTraces(), hasLength(handles));
      expect(unsized.completer.listeners, hasLength(1));
    }, skip: kIsWeb);

    testWidgets('a new image keeps the shape and picture until it loads', (
      tester,
    ) async {
      final image = (await tester.runAsync(
        () => createTestImage(width: 2, height: 1),
      ))!;
      await _pump(
        tester,
        ChatImageAttachment(image: _CachedImage(image), isSentByMe: true),
      );
      await tester.pump(const Duration(seconds: 1));

      await _pump(
        tester,
        ChatImageAttachment(image: _CachedImage(null), isSentByMe: true),
      );
      await tester.pump();

      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        2,
      );
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
    }, skip: kIsWeb);

    testWidgets('announces sending and failure', (tester) async {
      final semantics = tester.ensureSemantics();
      for (final (status, label) in [
        (MessageStatus.sending, 'Sending'),
        (MessageStatus.error, 'Not sent'),
      ]) {
        await _pump(
          tester,
          ChatImageAttachment(
            image: _CachedImage(null),
            isSentByMe: true,
            width: 4,
            height: 3,
            status: status,
            onTap: () {},
          ),
        );
        expect(find.semantics.byLabel(label), findsOne);
        expect(find.semantics.byLabel('Image'), findsOne);
      }
      semantics.dispose();
    });

    testWidgets('a corrupt ThumbHash falls back to a plain background', (
      tester,
    ) async {
      await _pump(
        tester,
        ChatImageAttachment(
          image: _CachedImage(null),
          placeholder: const ThumbhashImage('not a hash!'),
          isSentByMe: true,
          width: 4,
          height: 3,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a video announces its labels and length', (tester) async {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      ChatVideoAttachment(
        isSentByMe: false,
        duration: const Duration(seconds: 8),
        onTap: () {},
        labels: const ChatAttachmentLabels(playVideo: 'Lire la vidéo'),
      ),
    );

    expect(find.semantics.byLabel('Lire la vidéo'), findsOne);
    expect(find.semantics.byLabel('0:08'), findsOne);
    expect(find.semantics.byLabel('Play video'), findsNothing);
    semantics.dispose();
  });

  group('time and status', () {
    setUp(() => VideoPlayerPlatform.instance = FakeVideoPlayerPlatform());

    testWidgets('sit below the picture, clear of the failure badge', (
      tester,
    ) async {
      for (final bubble in [
        ChatImageAttachment(
          image: _CachedImage(null),
          isSentByMe: true,
          width: 4,
          height: 3,
          status: MessageStatus.error,
          time: _sentAt,
        ),
        ChatVideoAttachment(
          isSentByMe: true,
          width: 16,
          height: 9,
          duration: const Duration(seconds: 8),
          status: MessageStatus.error,
          time: _sentAt,
        ),
      ]) {
        await _pump(tester, bubble);
        final media = tester.getRect(find.byType(AspectRatio).first);
        final time = tester.getRect(find.text('09:41'));
        expect(time.top, greaterThanOrEqualTo(media.bottom));
        expect(
          media.contains(tester.getCenter(find.byType(CircleAvatar))),
          isTrue,
        );
      }
    });

    testWidgets('go on a line of their own, or inline beside the caption', (
      tester,
    ) async {
      for (final position in TimeAndStatusPosition.values) {
        await _pump(
          tester,
          ChatImageAttachment(
            image: _CachedImage(null),
            isSentByMe: true,
            width: 4,
            height: 3,
            caption: 'River hike',
            time: _sentAt,
            timeAndStatusPosition: position,
          ),
        );
        final bubble = tester.getRect(find.byType(ChatImageAttachment));
        final caption = tester.getRect(find.text('River hike'));
        final time = tester.getRect(find.text('09:41'));
        expect(
          time.top >= caption.bottom,
          position != TimeAndStatusPosition.inline,
          reason: '$position',
        );
        if (position == TimeAndStatusPosition.start) {
          expect(time.left, bubble.left + 12);
        } else {
          expect(time.right, bubble.right - 12);
        }
      }
    });
  });

  testWidgets('a file puts its top widget at the start and time at the end', (
    tester,
  ) async {
    await _pump(
      tester,
      ChatFileAttachment(
        name: 'a-rather-long-report-name.pdf',
        isSentByMe: false,
        time: _sentAt,
        topWidget: const Text('Alex'),
      ),
    );
    final bubble = tester.getRect(find.byType(ChatFileAttachment));
    expect(tester.getRect(find.text('Alex')).left, bubble.left + 12);
    // The visible time, after the copy that reserves its line.
    final time = tester.getRect(find.text('09:41').last);
    expect(time.right, bubble.right - 12);
    expect(time.bottom, bubble.bottom - 12);
    // Announced once.
    expect(
      tester.getSemantics(find.text('a-rather-long-report-name.pdf')).label,
      isNot(contains('09:41\n09:41')),
    );
  });

  testWidgets('a file takes a top widget that lays out by its constraints', (
    tester,
  ) async {
    await _pump(
      tester,
      ChatFileAttachment(
        name: 'report.pdf',
        isSentByMe: false,
        time: _sentAt,
        topWidget: LayoutBuilder(builder: (_, _) => const Text('Alex')),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Alex'), findsOneWidget);
  });

  testWidgets('a file shortens its details to fit large text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
          child: Scaffold(
            body: Center(
              child: ChatFileAttachment(
                name: 'report.pdf',
                size: 24100000,
                isSentByMe: true,
                status: MessageStatus.sent,
                time: _sentAt,
                timeAndStatusPosition: TimeAndStatusPosition.inline,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed bubble image loads again when next built', (
    tester,
  ) async {
    final failing = _FailingImage();
    // Resized, as the bubble shows a full image without a thumbnail.
    final image = ResizeImage(failing, width: 10);
    Future<void> pumpBubble() => _pump(
      tester,
      ChatImageAttachment(image: image, isSentByMe: true, width: 4, height: 3),
    );

    await pumpBubble();
    await tester.pump();
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);

    // Scrolled away, and back.
    await _pump(tester, const SizedBox());
    await pumpBubble();
    expect(failing.loads, 2);
  });
}

/// An image that fails to load, counting its loads.
class _FailingImage extends ImageProvider<_FailingImage> {
  var loads = 0;

  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_FailingImage key, ImageDecoderCallback _) {
    loads++;
    return OneFrameImageStreamCompleter(Future.error(StateError('offline')));
  }
}
