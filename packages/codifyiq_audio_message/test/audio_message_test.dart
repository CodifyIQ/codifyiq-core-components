import 'dart:async';

import 'package:codifyiq_audio_message/codifyiq_audio_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_audio_backend.dart';

final _a = AudioMessageSource.uri(Uri.parse('https://example.com/a.m4a'));
final _b = AudioMessageSource.uri(Uri.parse('https://example.com/b.m4a'));

void main() {
  late FakeAudioBackend backend;
  late AudioMessageController controller;

  setUp(() {
    backend = FakeAudioBackend();
    controller = AudioMessageController(backend: backend);
  });

  group('AudioMessageController', () {
    test('loads the source on the first play, then plays', () async {
      await controller.play('a', _a);

      expect(backend.calls, ['setSource', 'play']);
      expect(backend.sources, [_a]);
      expect(controller.currentId, 'a');
      expect(controller.state, AudioPlaybackState.playing);
    });

    test('resumes a paused message without reloading it', () async {
      await controller.play('a', _a);
      await controller.pause();
      await controller.play('a', _a);

      expect(backend.calls, ['setSource', 'play', 'pause', 'play']);
    });

    test('playing another message replaces the current one', () async {
      await controller.play('a', _a);
      backend.emitTimes(
        const Duration(seconds: 10),
        const Duration(seconds: 4),
      );
      await controller.play('b', _b);

      expect(backend.sources, [_a, _b]);
      expect(controller.currentId, 'b');
      expect(controller.position, Duration.zero);
    });

    test('plays again from the start after completing', () async {
      await controller.play('a', _a);
      backend.emit(AudioBackendProcessingState.completed);
      await controller.play('a', _a);

      expect(backend.calls, [
        'setSource',
        'play',
        'seek 0:00:00.000000',
        'play',
      ]);
    });

    test('reports a load error and retries it on the next play', () async {
      backend.loadError = Exception('404');
      await controller.play('a', _a);
      backend.emit(AudioBackendProcessingState.idle);

      expect(controller.state, AudioPlaybackState.error);
      expect(controller.rawError, contains('404'));

      backend.loadError = null;
      await controller.play('a', _a);
      expect(backend.calls, ['setSource', 'setSource', 'play']);
      expect(controller.state, AudioPlaybackState.playing);
    });

    test('reports errors from the backend streams as an error', () async {
      await controller.play('a', _a);
      backend.emitError(Exception('decoder failed'));

      expect(controller.state, AudioPlaybackState.error);
      expect(controller.rawError, contains('decoder failed'));
    });

    test('pausing while loading stops the message from starting', () async {
      final slow = Completer<void>();
      backend.pendingLoad = slow;
      final playing = controller.play('a', _a);
      await controller.pause();
      slow.complete();
      await playing;

      expect(backend.calls, isNot(contains('play')));
      expect(controller.state, AudioPlaybackState.idle);
    });

    test('ignores the previous message\'s events while loading', () async {
      await controller.play('a', _a);
      final slow = Completer<void>();
      backend.pendingLoad = slow;
      final playing = controller.play('b', _b);
      backend.emitTimes(
        const Duration(seconds: 10),
        const Duration(seconds: 4),
      );
      backend.emit(AudioBackendProcessingState.ready, isPlaying: true);

      expect(controller.position, Duration.zero);
      expect(controller.state, AudioPlaybackState.loading);
      slow.complete();
      await playing;
    });

    test('ignores a load that a newer one replaced', () async {
      final slow = Completer<void>();
      backend.pendingLoad = slow;
      final first = controller.play('a', _a);
      await controller.play('b', _b);
      backend.loadError = Exception('interrupted');
      slow.complete();
      await first;

      expect(controller.currentId, 'b');
      expect(controller.state, AudioPlaybackState.playing);
      expect(backend.calls.where((call) => call == 'play'), hasLength(1));
    });
  });

  group('AudioMessageWidget', () {
    Future<void> pumpPlayers(WidgetTester tester, List<Widget> players) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Column(children: players)),
          ),
        );

    testWidgets('shows the known duration before loading', (tester) async {
      await pumpPlayers(tester, [
        AudioMessageWidget(
          source: _a,
          controller: controller,
          duration: const Duration(seconds: 42),
        ),
      ]);

      expect(find.text('00:00 / 00:42'), findsOneWidget);
      expect(backend.calls, isEmpty);
    });

    testWidgets('a shared controller plays one message at a time', (
      tester,
    ) async {
      await pumpPlayers(tester, [
        AudioMessageWidget(id: 'a', source: _a, controller: controller),
        AudioMessageWidget(id: 'b', source: _b, controller: controller),
      ]);

      await tester.tap(find.byTooltip('Play').first);
      await tester.pump();
      expect(find.byTooltip('Pause'), findsOneWidget);

      await tester.tap(find.byTooltip('Play'));
      await tester.pump();
      expect(controller.currentId, 'b');
      // The first player is back to Play, the second shows Pause.
      expect(find.byTooltip('Play'), findsOneWidget);
      expect(
        tester.getCenter(find.byTooltip('Pause')).dy,
        greaterThan(tester.getCenter(find.byTooltip('Play')).dy),
      );
    });

    testWidgets('keeps playing when a player with a shared controller is '
        'removed, and shows the position when it returns', (tester) async {
      final player = AudioMessageWidget(
        id: 'a',
        source: _a,
        controller: controller,
      );
      await pumpPlayers(tester, [player]);
      await tester.tap(find.byTooltip('Play'));
      await tester.pump();

      await pumpPlayers(tester, []);
      expect(backend.calls, isNot(contains('pause')));
      expect(backend.calls, isNot(contains('dispose')));

      backend.emitTimes(
        const Duration(seconds: 30),
        const Duration(seconds: 7),
      );
      await pumpPlayers(tester, [player]);
      expect(find.text('00:07 / 00:30'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsOneWidget);
    });

    testWidgets('a new source under the same id is a new message, and the '
        'old one stops', (tester) async {
      await pumpPlayers(tester, [
        AudioMessageWidget(id: 'a', source: _a, controller: controller),
      ]);
      await tester.tap(find.byTooltip('Play'));
      await tester.pump();
      backend.emitTimes(
        const Duration(seconds: 30),
        const Duration(seconds: 7),
      );

      // For example, a sent voice note's local file replaced by its upload.
      await pumpPlayers(tester, [
        AudioMessageWidget(id: 'a', source: _b, controller: controller),
      ]);
      expect(backend.calls.last, 'pause');
      expect(find.byTooltip('Play'), findsOneWidget);
      // Not the old file's position.
      expect(find.text('00:00 / 00:00'), findsOneWidget);
    });

    testWidgets('players without an id are separate messages', (tester) async {
      await pumpPlayers(tester, [
        AudioMessageWidget(source: _a, controller: controller),
        AudioMessageWidget(source: _a, controller: controller),
      ]);
      await tester.tap(find.byTooltip('Play').first);
      await tester.pump();

      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.byTooltip('Play'), findsOneWidget);
    });

    testWidgets('the button and slider share the default colour', (
      tester,
    ) async {
      await pumpPlayers(tester, [
        AudioMessageWidget(source: _a, controller: controller),
      ]);
      final primary = Theme.of(
        tester.element(find.byType(AudioMessageWidget)),
      ).colorScheme.primary;

      expect(tester.widget<IconButton>(find.byType(IconButton)).color, primary);
      expect(tester.widget<Slider>(find.byType(Slider)).activeColor, primary);
    });

    testWidgets('shows the error and retries', (tester) async {
      backend.loadError = Exception('404');
      await pumpPlayers(tester, [
        AudioMessageWidget(source: _a, controller: controller),
      ]);
      await tester.tap(find.byTooltip('Play'));
      await tester.pump();
      expect(find.text('Could not load audio'), findsOneWidget);

      backend.loadError = null;
      await tester.tap(find.byTooltip('Retry'));
      await tester.pump();
      expect(find.byTooltip('Pause'), findsOneWidget);
    });

    testWidgets('uses the given colour and text style', (tester) async {
      await pumpPlayers(tester, [
        AudioMessageWidget(
          source: _a,
          controller: controller,
          color: Colors.pink,
          textStyle: const TextStyle(color: Colors.teal),
        ),
      ]);

      expect(
        tester.widget<IconButton>(find.byType(IconButton)).color,
        Colors.pink,
      );
      expect(
        tester.widget<Slider>(find.byType(Slider)).activeColor,
        Colors.pink,
      );
      expect(
        tester.widget<Text>(find.text('00:00 / 00:00')).style?.color,
        Colors.teal,
      );
    });
  });

  test('sources compare by value', () {
    expect(
      AudioMessageSource.uri(
        Uri.parse('https://example.com/a.m4a'),
        headers: const {'Authorization': 'x'},
      ),
      AudioMessageSource.uri(
        Uri.parse('https://example.com/a.m4a'),
        headers: const {'Authorization': 'x'},
      ),
    );
    expect(
      const AudioMessageSource.file('/a.m4a'),
      isNot(const AudioMessageSource.asset('/a.m4a')),
    );
  });
}
