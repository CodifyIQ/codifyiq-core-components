import 'package:codifyiq_video_viewer/codifyiq_video_viewer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_player_platform.dart';
import 'fake_wakelock.dart';

void main() {
  late FakeVideoPlayerPlatform platform;
  late FakeWakelock wakelock;

  setUp(() {
    platform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
    wakelock = FakeWakelock.install();
  });

  // Touch platforms wait to see whether a tap is the first of a double tap.
  Future<void> tapVideo(WidgetTester tester, {double xFraction = 0.5}) async {
    final rect = tester.getRect(find.byType(VideoViewerWidget));
    await tester.tapAt(
      Offset(rect.left + rect.width * xFraction, rect.center.dy),
    );
    await tester.pump(kDoubleTapTimeout);
  }

  Future<void> doubleTapVideo(
    WidgetTester tester, {
    required double xFraction,
  }) async {
    final rect = tester.getRect(find.byType(VideoViewerWidget));
    final position = Offset(rect.left + rect.width * xFraction, rect.center.dy);
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(position);
    await tester.pump();
  }

  final source = VideoSource.uri(
    Uri.parse('https://example.com/clip.mp4'),
    headers: const {'Authorization': 'Bearer token'},
  );

  Future<void> pumpPlayer(
    WidgetTester tester, {
    VideoSource? videoSource,
    bool autoPlay = false,
    bool looping = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoViewerWidget(
            source: videoSource ?? source,
            autoPlay: autoPlay,
            looping: looping,
          ),
        ),
      ),
    );
    // Let the fake player report that it has loaded.
    await tester.pump();
    await tester.pump();
  }

  // Playing starts timers (position polling, controls auto-hide), so unmount
  // the player before a test ends.
  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  group('hidden players', () {
    // Calls made to the player since the last play.
    Iterable<String> callsSincePlay() =>
        platform.calls.skip(platform.calls.lastIndexOf('play'));

    testWidgets('pause under a route that covers them and stay paused', (
      tester,
    ) async {
      await pumpPlayer(tester);
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
      await tester.pumpAndSettle();
      expect(callsSincePlay(), contains('pause'));

      navigator.pop();
      await tester.pumpAndSettle();
      expect(callsSincePlay(), contains('pause'));
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('keep playing under a dialog', (tester) async {
      await pumpPlayer(tester);
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      showDialog<void>(
        context: tester.element(find.byType(VideoViewerWidget)),
        builder: (_) => const AlertDialog(content: Text('Hello')),
      );
      await tester.pumpAndSettle();

      expect(callsSincePlay(), isNot(contains('pause')));
      await unmount(tester);
    });

    Future<void> pumpInTickerMode(
      WidgetTester tester, {
      required bool enabled,
      bool autoPlay = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TickerMode(
              enabled: enabled,
              child: VideoViewerWidget(source: source, autoPlay: autoPlay),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('pause when their tab is switched away from', (tester) async {
      await pumpInTickerMode(tester, enabled: true);
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      await pumpInTickerMode(tester, enabled: false);

      expect(callsSincePlay(), contains('pause'));
      await unmount(tester);
    });

    testWidgets('do not auto-play while hidden', (tester) async {
      await pumpInTickerMode(tester, enabled: false, autoPlay: true);

      expect(platform.calls, isNot(contains('play')));
      await unmount(tester);
    });
  });

  testWidgets('loads a network source with its headers', (tester) async {
    await pumpPlayer(tester);

    final dataSource = platform.dataSources.single;
    expect(dataSource.uri, 'https://example.com/clip.mp4');
    expect(dataSource.httpHeaders, {'Authorization': 'Bearer token'});
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);
  });

  testWidgets('loads an asset source', (tester) async {
    await pumpPlayer(
      tester,
      videoSource: const VideoSource.asset('assets/clip.mp4'),
    );

    final dataSource = platform.dataSources.single;
    expect(dataSource.sourceType, DataSourceType.asset);
    expect(dataSource.asset, 'assets/clip.mp4');
  });

  testWidgets('does not play until asked, then plays and pauses', (
    tester,
  ) async {
    await pumpPlayer(tester);
    expect(platform.calls, isNot(contains('play')));

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(platform.calls, contains('play'));
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    expect(platform.calls.last, 'pause');
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('autoPlay starts playback once loaded', (tester) async {
    await pumpPlayer(tester, autoPlay: true);

    expect(platform.calls, contains('play'));
    await unmount(tester);
  });

  testWidgets('controls hide during playback and return on tap', (
    tester,
  ) async {
    await pumpPlayer(tester, autoPlay: true);
    AnimatedOpacity controls() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(controls().opacity, 1);

    await tester.pump(const Duration(seconds: 4));
    expect(controls().opacity, 0);

    await tapVideo(tester);
    expect(controls().opacity, 1);
    await unmount(tester);
  });

  testWidgets('a tap elsewhere on screen hides the controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(height: 300, child: VideoViewerWidget(source: source)),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    AnimatedOpacity controls() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    const elsewhere = Offset(400, 500);

    // A paused video keeps its controls.
    await tester.tapAt(elsewhere);
    await tester.pump();
    expect(controls().opacity, 1);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(controls().opacity, 1);

    await tester.tapAt(elsewhere);
    await tester.pump();
    expect(controls().opacity, 0);
    await unmount(tester);
  });

  testWidgets('keeps the screen awake only while playing', (tester) async {
    await pumpPlayer(tester);
    expect(wakelock.isEnabled, isFalse);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(wakelock.isEnabled, isTrue);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    expect(wakelock.isEnabled, isFalse);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    await unmount(tester);
    expect(wakelock.isEnabled, isFalse);
  });

  testWidgets(
    'on touch platforms, double tap jumps back or forward ten seconds',
    (tester) async {
      await pumpPlayer(tester);

      await doubleTapVideo(tester, xFraction: 0.8);
      expect(platform.soughtTo, const Duration(seconds: 10));
      expect(find.byIcon(Icons.forward_10), findsOneWidget);

      await doubleTapVideo(tester, xFraction: 0.2);
      expect(platform.soughtTo, Duration.zero);
      expect(find.byIcon(Icons.replay_10), findsOneWidget);

      // Not past the start, and the feedback goes away.
      await doubleTapVideo(tester, xFraction: 0.2);
      expect(platform.soughtTo, Duration.zero);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.replay_10), findsNothing);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('double tap does not seek while the length is unknown', (
    tester,
  ) async {
    platform.duration = Duration.zero;
    await pumpPlayer(tester);

    await doubleTapVideo(tester, xFraction: 0.8);
    expect(platform.calls, isNot(contains('seekTo')));
    await tester.pump(kDoubleTapTimeout);
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('the screen stays awake while any player plays', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(child: VideoViewerWidget(source: source)),
              Expanded(
                child: VideoViewerWidget(
                  source: VideoSource.uri(
                    Uri.parse('https://example.com/other.mp4'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    Future<void> tapIn(int player, IconData icon) async {
      await tester.tap(
        find.descendant(
          of: find.byType(VideoViewerWidget).at(player),
          matching: find.byIcon(icon),
        ),
      );
      await tester.pump();
    }

    // A tap on one player hides the other's controls, so bring them back.
    Future<void> showControlsOf(int player) async {
      await tester.tapAt(
        tester.getCenter(find.byType(VideoViewerWidget).at(player)),
      );
      await tester.pump(kDoubleTapTimeout);
    }

    await tapIn(0, Icons.play_arrow);
    await tapIn(1, Icons.play_arrow);
    // The first one pauses; the second still plays.
    await showControlsOf(0);
    await tapIn(0, Icons.pause);
    expect(wakelock.isEnabled, isTrue);

    await showControlsOf(1);
    await tapIn(1, Icons.pause);
    expect(wakelock.isEnabled, isFalse);
  });

  testWidgets('on desktop, double click does not seek', (tester) async {
    await pumpPlayer(tester);

    await doubleTapVideo(tester, xFraction: 0.8);
    expect(platform.calls, isNot(contains('seekTo')));
  }, variant: TargetPlatformVariant.desktop());

  testWidgets('replaying a finished video shows the controls again', (
    tester,
  ) async {
    await pumpPlayer(tester, autoPlay: true);
    AnimatedOpacity controls() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    await tester.pump(const Duration(seconds: 4));
    expect(controls().opacity, 0);

    platform.emit(VideoEvent(eventType: VideoEventType.completed));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byIcon(Icons.replay));
    await tester.pump();
    await tester.pump();

    // Playing again, with the controls up until the hide delay passes.
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(controls().opacity, 1);
    await tester.pump(const Duration(seconds: 4));
    expect(controls().opacity, 0);
    await unmount(tester);
  });

  testWidgets('the mute button toggles the volume', (tester) async {
    await pumpPlayer(tester);

    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pump();
    expect(platform.volume, 0);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);

    await tester.tap(find.byIcon(Icons.volume_off));
    await tester.pump();
    expect(platform.volume, 1);
  });

  testWidgets('desktop gets a volume slider, and unmuting restores its level', (
    tester,
  ) async {
    await pumpPlayer(tester);
    final volumeSlider = find.byType(Slider).last;
    expect(find.byType(Slider), findsNWidgets(2));

    // The middle of the slider: half volume.
    await tester.tap(volumeSlider);
    await tester.pump();
    expect(platform.volume, closeTo(0.5, 0.05));

    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pump();
    expect(platform.volume, 0);

    await tester.tap(find.byIcon(Icons.volume_off));
    await tester.pump();
    expect(platform.volume, closeTo(0.5, 0.05));
  }, variant: TargetPlatformVariant.desktop());

  testWidgets(
    'phones and tablets get no volume slider',
    (tester) async {
      await pumpPlayer(tester);

      expect(find.byType(Slider), findsOneWidget);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('scrubbing seeks to the chosen position', (tester) async {
    await pumpPlayer(tester);

    // Tap the middle of the slider: halfway through the 90 second video.
    await tester.tap(find.byType(Slider));
    await tester.pump();

    expect(platform.calls, contains('seekTo'));
    expect(platform.soughtTo!.inSeconds, closeTo(45, 2));
  });

  testWidgets('the scrubber is disabled when the length is unknown', (
    tester,
  ) async {
    platform.duration = Duration.zero;
    await pumpPlayer(tester);

    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
  });

  testWidgets('a finished video offers replay from the start', (tester) async {
    await pumpPlayer(tester);
    platform.emit(VideoEvent(eventType: VideoEventType.completed));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.replay), findsOneWidget);
    expect(platform.soughtTo, const Duration(seconds: 90));

    await tester.tap(find.byIcon(Icons.replay));
    await tester.pump();
    await tester.pump();
    expect(platform.soughtTo, Duration.zero);
    expect(platform.calls, contains('play'));
    await unmount(tester);
  });

  testWidgets('passes looping to the player', (tester) async {
    await pumpPlayer(tester, looping: true);
    expect(platform.calls, contains('setLooping true'));
  });

  testWidgets('a failed load shows an error, and Retry loads again', (
    tester,
  ) async {
    platform.failToLoad = true;
    await pumpPlayer(tester);
    expect(find.text('Could not load video'), findsOneWidget);

    platform.failToLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(platform.dataSources, hasLength(2));
    expect(find.text('Could not load video'), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('a player that fails to be created shows the error UI', (
    tester,
  ) async {
    platform.failToCreate = true;
    await pumpPlayer(tester);

    expect(find.text('Could not load video'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    platform.failToCreate = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('errorBuilder replaces the default error UI', (tester) async {
    platform.failToLoad = true;
    await tester.pumpWidget(
      MaterialApp(
        home: VideoViewerWidget(
          source: source,
          errorBuilder: (context, error) => const Text('custom error'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('custom error'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('a new source replaces the player', (tester) async {
    await pumpPlayer(tester);
    await pumpPlayer(
      tester,
      videoSource: VideoSource.uri(Uri.parse('https://example.com/other.mp4')),
    );
    // The player finishes disposing outside the test's fake clock.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    expect(platform.dataSources.map((d) => d.uri), [
      'https://example.com/clip.mp4',
      'https://example.com/other.mp4',
    ]);
    expect(platform.calls, contains('dispose'));
  });

  testWidgets('new headers alone do not restart the video', (tester) async {
    await pumpPlayer(tester);
    await pumpPlayer(
      tester,
      videoSource: VideoSource.uri(
        Uri.parse('https://example.com/clip.mp4'),
        headers: const {'Authorization': 'Bearer refreshed'},
      ),
    );

    expect(platform.dataSources, hasLength(1));
  });

  testWidgets('a muted video stays muted when the source changes', (
    tester,
  ) async {
    await pumpPlayer(tester);
    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pump();

    platform.volume = null;
    await pumpPlayer(
      tester,
      videoSource: VideoSource.uri(Uri.parse('https://example.com/other.mp4')),
    );
    await tester.pump();

    expect(platform.dataSources, hasLength(2));
    expect(platform.volume, 0);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
  });

  testWidgets('a file source shows the error UI on web', (tester) async {
    await pumpPlayer(
      tester,
      videoSource: const VideoSource.file('/tmp/clip.mp4'),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Could not load video'), findsOneWidget);
    expect(platform.dataSources, isEmpty);
  }, skip: !kIsWeb);

  test('sources compare by value', () {
    final uri = Uri.parse('https://example.com/clip.mp4');
    expect(
      VideoSource.uri(uri, headers: const {'a': '1'}),
      VideoSource.uri(uri, headers: const {'a': '1'}),
    );
    expect(
      VideoSource.uri(uri, headers: const {'a': '1'}),
      isNot(VideoSource.uri(uri, headers: const {'a': '2'})),
    );
    expect(const VideoSource.file('/a.mp4'), const VideoSource.file('/a.mp4'));
    expect(
      const VideoSource.asset('a.mp4'),
      isNot(const VideoSource.asset('a.mp4', package: 'pkg')),
    );
  });
}
