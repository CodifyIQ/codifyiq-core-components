import 'package:codifyiq_video_viewer/codifyiq_video_viewer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_player_platform.dart';

void main() {
  late FakeVideoPlayerPlatform platform;

  setUp(() {
    platform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  final source = VideoSource.uri(Uri.parse('https://example.com/clip.mp4'));

  Future<void> pumpScreen(
    WidgetTester tester, {
    String? title,
    VoidCallback? onClose,
    VideoViewerShareCallback? onShare,
    VoidCallback? onDownload,
    List<VideoViewerAction> actions = const [],
    bool autoPlay = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VideoViewerScreen(
                    source: source,
                    title: title,
                    onClose: onClose,
                    onShare: onShare,
                    onDownload: onDownload,
                    actions: actions,
                    autoPlay: autoPlay,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the title and closes back to the previous route', (
    tester,
  ) async {
    await pumpScreen(tester, title: 'clip.mp4');
    expect(find.text('clip.mp4'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(VideoViewerScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('onClose replaces popping the route', (tester) async {
    var closes = 0;
    await pumpScreen(tester, onClose: () => closes++);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(closes, 1);
    expect(find.byType(VideoViewerScreen), findsOneWidget);
  });

  testWidgets('hides the close button with no route to go back to', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: VideoViewerScreen(source: source)),
    );
    await tester.pump();

    expect(find.byIcon(Icons.close), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('plays automatically by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: VideoViewerScreen(source: source)),
    );
    await tester.pump();
    await tester.pump();

    expect(platform.calls, contains('play'));
    // Unmount so the playback timers stop before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('hides Share, Download and the overflow menu by default', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.byIcon(Icons.share_outlined), findsNothing);
    expect(find.byIcon(Icons.download_outlined), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  // Share and Download swap places on web, so each layout has its own test.
  // `flutter test` covers the mobile one; add `--platform chrome` for web.
  testWidgets(
    'share reports the button rect; download and custom actions are in the '
    'overflow',
    (tester) async {
      Rect? origin;
      final chosen = <String>[];
      await pumpScreen(
        tester,
        onShare: (rect) => origin = rect,
        onDownload: () => chosen.add('download'),
        actions: [
          VideoViewerAction(
            label: 'Copy link',
            icon: Icons.link,
            onSelected: () => chosen.add('copy'),
          ),
        ],
      );
      await tester.tap(find.byIcon(Icons.share_outlined));
      final shareCenter = tester.getCenter(find.byIcon(Icons.share_outlined));
      expect(origin?.contains(shareCenter), isTrue);

      for (final label in ['Download', 'Copy link']) {
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(chosen, ['download', 'copy']);
    },
    skip: kIsWeb,
  );

  testWidgets('on web, download is the button and share is in the overflow', (
    tester,
  ) async {
    var shares = 0;
    var downloads = 0;
    await pumpScreen(
      tester,
      onShare: (rect) => shares++,
      onDownload: () => downloads++,
    );
    await tester.tap(find.byIcon(Icons.download_outlined));
    expect(find.byIcon(Icons.share_outlined), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(downloads, 1);
    expect(shares, 1);
  }, skip: !kIsWeb);
}
