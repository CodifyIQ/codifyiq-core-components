import 'package:codifyiq_video_viewer/codifyiq_video_viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester, VideoThumbnailTile tile) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 320, child: tile)),
        ),
      ),
    );
  }

  testWidgets('shows a play badge and reports taps', (tester) async {
    var taps = 0;
    await pumpTile(tester, VideoThumbnailTile(onTap: () => taps++));

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tester.tap(find.byType(VideoThumbnailTile));
    expect(taps, 1);
  });

  testWidgets('is announced as a button only when it can be tapped', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VideoThumbnailTile())),
    );
    expect(find.bySemanticsLabel('Play video'), findsNothing);
    expect(find.bySemanticsLabel('Video'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VideoThumbnailTile(onTap: () {})),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Play video')),
      matchesSemantics(label: 'Play video', isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('announces semanticLabel instead of the default', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpTile(
      tester,
      VideoThumbnailTile(onTap: () {}, semanticLabel: 'Vidéo'),
    );
    expect(find.bySemanticsLabel('Vidéo'), findsOneWidget);
    expect(find.bySemanticsLabel('Play video'), findsNothing);
    semantics.dispose();
  });

  testWidgets('keeps its aspect ratio', (tester) async {
    await pumpTile(tester, const VideoThumbnailTile(aspectRatio: 4 / 3));
    expect(
      tester.getSize(find.byType(VideoThumbnailTile)),
      const Size(320, 240),
    );
  });

  testWidgets('formats the duration, with hours only when needed', (
    tester,
  ) async {
    await pumpTile(
      tester,
      const VideoThumbnailTile(duration: Duration(minutes: 1, seconds: 5)),
    );
    expect(find.text('1:05'), findsOneWidget);

    await pumpTile(
      tester,
      const VideoThumbnailTile(
        duration: Duration(hours: 1, minutes: 2, seconds: 3),
      ),
    );
    expect(find.text('1:02:03'), findsOneWidget);
  });

  test('formatVideoDuration matches the tile', () {
    expect(formatVideoDuration(const Duration(seconds: 8)), '0:08');
    expect(
      formatVideoDuration(const Duration(hours: 2, seconds: 1)),
      '2:00:01',
    );
  });

  testWidgets('shows no duration when none is given', (tester) async {
    await pumpTile(tester, const VideoThumbnailTile());
    expect(find.byType(Text), findsNothing);
  });
}
