import 'package:codifyiq_video_viewer/codifyiq_video_viewer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_player_platform.dart';
import 'fake_wakelock.dart';

void main() {
  late FakeVideoPlayerPlatform platform;
  late List<MethodCall> systemCalls;

  setUp(() {
    platform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
    FakeWakelock.install();
    systemCalls = [];
  });

  final source = VideoSource.uri(Uri.parse('https://example.com/clip.mp4'));

  Future<void> pumpPlayer(
    WidgetTester tester, {
    VideoSource? videoSource,
    bool allowFullScreen = true,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        systemCalls.add(call);
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoViewerWidget(
            source: videoSource ?? source,
            allowFullScreen: allowFullScreen,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  List<String> chromeCalls() => [
    for (final call in systemCalls)
      if (call.method == 'SystemChrome.setEnabledSystemUIMode' ||
          call.method == 'SystemChrome.setPreferredOrientations')
        call.method,
  ];

  testWidgets(
    'full screen carries on the same video, then hands it back inline',
    (tester) async {
      await pumpPlayer(tester);
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pumpAndSettle();

      // One player on screen, the same one: nothing was loaded again.
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(platform.dataSources, hasLength(1));
      expect(platform.calls.where((call) => call == 'play'), hasLength(1));
      if (kIsWeb) {
        // Browsers only allow these from their own full-screen mode.
        expect(chromeCalls(), isEmpty);
      } else {
        // Bars hidden, and the 16:9 video turned to landscape.
        expect(chromeCalls(), [
          'SystemChrome.setEnabledSystemUIMode',
          'SystemChrome.setPreferredOrientations',
        ]);
        expect(systemCalls.last.arguments, [
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight',
        ]);
      }

      await tester.tap(find.byIcon(Icons.fullscreen_exit));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(platform.dataSources, hasLength(1));
      expect(
        platform.calls.skip(platform.calls.indexOf('play')),
        isNot(contains('pause')),
      );
      if (!kIsWeb) {
        expect(
          systemCalls.last.method,
          'SystemChrome.setPreferredOrientations',
        );
        expect(systemCalls.last.arguments, isEmpty);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('the inline player waits for full screen to fade out', (
    tester,
  ) async {
    await pumpPlayer(tester);
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.fullscreen_exit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid fade: only the full-screen page shows the video.
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
  });

  testWidgets('onExitFullScreen runs after the system UI is put back', (
    tester,
  ) async {
    var exitCalls = 0;
    var systemCallsAtExit = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        systemCalls.add(call);
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoViewerWidget(
            source: source,
            onExitFullScreen: () {
              exitCalls++;
              systemCallsAtExit = chromeCalls().length;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();
    expect(exitCalls, 0);

    await tester.tap(find.byIcon(Icons.fullscreen_exit));
    await tester.pumpAndSettle();
    expect(exitCalls, 1);
    expect(systemCallsAtExit, chromeCalls().length);
  });

  testWidgets('back closes full screen', (tester) async {
    await pumpPlayer(tester);
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
  });

  testWidgets('a new source closes full screen and loads inline', (
    tester,
  ) async {
    await pumpPlayer(tester);
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();

    await pumpPlayer(
      tester,
      videoSource: VideoSource.uri(Uri.parse('https://example.com/other.mp4')),
    );
    await tester.pumpAndSettle();
    // The old player finishes disposing outside the test's fake clock.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    expect(find.byIcon(Icons.fullscreen_exit), findsNothing);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    expect(platform.calls, contains('dispose'));
  });

  testWidgets('allowFullScreen false hides the button', (tester) async {
    await pumpPlayer(tester, allowFullScreen: false);

    expect(find.byIcon(Icons.fullscreen), findsNothing);
  });
}
