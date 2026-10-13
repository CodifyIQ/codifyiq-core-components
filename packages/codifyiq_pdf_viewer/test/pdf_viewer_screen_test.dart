import 'package:codifyiq_pdf_viewer/codifyiq_pdf_viewer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // The screen's chrome is under test, not PDF rendering, so any bytes do:
  // the viewer just shows its error UI for them.
  final source = PdfSource.bytes(Uint8List(0));

  Future<void> pumpScreen(
    WidgetTester tester, {
    String? title,
    PdfViewerShareCallback? onShare,
    VoidCallback? onDownload,
    List<PdfViewerAction> actions = const [],
    bool enableSearch = true,
    VoidCallback? onClose,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PdfViewerScreen(
                    source: source,
                    title: title,
                    onShare: onShare,
                    onDownload: onDownload,
                    actions: actions,
                    enableSearch: enableSearch,
                    onClose: onClose,
                    errorBuilder: (context, error) => const Text('load error'),
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
    await pumpScreen(tester, title: 'report.pdf');
    expect(find.text('report.pdf'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(PdfViewerScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('onClose replaces popping the route', (tester) async {
    var closes = 0;
    await pumpScreen(tester, onClose: () => closes++);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(closes, 1);
    expect(find.byType(PdfViewerScreen), findsOneWidget);
  });

  testWidgets('hides the close button with no route to go back to', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: PdfViewerScreen(source: source)));

    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('shows the close button with onClose even as the first route', (
    tester,
  ) async {
    var closes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PdfViewerScreen(source: source, onClose: () => closes++),
      ),
    );
    await tester.tap(find.byIcon(Icons.close));

    expect(closes, 1);
  });

  test('rejects invalid zoom bounds and page numbers up front', () {
    expect(
      () => PdfViewerScreen(source: source, minScale: 5),
      throwsAssertionError,
    );
    expect(
      () => PdfViewerScreen(source: source, initialPageNumber: 0),
      throwsAssertionError,
    );
  });

  testWidgets('passes viewer options through and insets only the bottom', (
    tester,
  ) async {
    void onProgress(int received, int? total) {}
    await tester.pumpWidget(
      MaterialApp(
        home: PdfViewerScreen(
          source: source,
          showPageIndicator: false,
          showZoomControlsOnWeb: false,
          showDownloadProgress: false,
          onDownloadProgress: onProgress,
          searchDebounce: const Duration(seconds: 1),
        ),
      ),
    );
    final viewer = tester.widget<PdfViewerWidget>(find.byType(PdfViewerWidget));
    expect(viewer.showPageIndicator, isFalse);
    expect(viewer.showZoomControlsOnWeb, isFalse);
    expect(viewer.showDownloadProgress, isFalse);
    expect(viewer.onDownloadProgress, onProgress);
    expect(viewer.searchDebounce, const Duration(seconds: 1));

    final safeArea = tester.widget<SafeArea>(
      find.ancestor(
        of: find.byType(PdfViewerWidget),
        matching: find.byType(SafeArea),
      ),
    );
    expect(
      (safeArea.top, safeArea.left, safeArea.right, safeArea.bottom),
      (false, false, false, true),
    );
  });

  testWidgets('hides Share, Download and the overflow menu by default', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.byIcon(Icons.share_outlined), findsNothing);
    expect(find.byIcon(Icons.download_outlined), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  // Share and Download swap places on web, so each layout has its own tests.
  // `flutter test` covers the mobile one; add `--platform chrome` for web.
  testWidgets('share reports the button rect and download is in the overflow', (
    tester,
  ) async {
    Rect? origin;
    var downloads = 0;
    await pumpScreen(
      tester,
      onShare: (rect) => origin = rect,
      onDownload: () => downloads++,
    );
    await tester.tap(find.byIcon(Icons.share_outlined));
    expect(find.byIcon(Icons.download_outlined), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    final shareCenter = tester.getCenter(find.byIcon(Icons.share_outlined));
    expect(origin?.contains(shareCenter), isTrue);
    expect(downloads, 1);
  }, skip: kIsWeb);

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

  testWidgets('custom actions follow Download in the overflow menu', (
    tester,
  ) async {
    var opened = 0;
    await pumpScreen(
      tester,
      onDownload: () {},
      actions: [
        PdfViewerAction(
          label: 'Open in browser',
          icon: Icons.open_in_new,
          onSelected: () => opened++,
        ),
      ],
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Download')).dy,
      lessThan(tester.getTopLeft(find.text('Open in browser')).dy),
    );
    await tester.tap(find.text('Open in browser'));
    await tester.pumpAndSettle();

    expect(opened, 1);
  }, skip: kIsWeb);

  testWidgets('the search button shows and hides the search bar', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Search in document'), findsNothing);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.text('Search in document'), findsOneWidget);
    // Ready to type in without a second tap.
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isTrue);

    await tester.tap(find.byIcon(Icons.search_off));
    await tester.pumpAndSettle();
    expect(find.text('Search in document'), findsNothing);
  });

  testWidgets('back closes the search bar first, then the screen', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Search in document'), findsNothing);
    expect(find.byType(PdfViewerScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PdfViewerScreen), findsNothing);
  });

  testWidgets('the close button closes the screen even while searching', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(PdfViewerScreen), findsNothing);
  });

  testWidgets('enableSearch: false removes the search button', (tester) async {
    await pumpScreen(tester, enableSearch: false);
    expect(find.byIcon(Icons.search), findsNothing);
  });
}
