import 'package:codifyiq_brightness_button/codifyiq_brightness_button.dart';
import 'package:codifyiq_pdf_viewer/codifyiq_pdf_viewer.dart';
import 'package:flutter/material.dart';

/// An example page that demonstrates the [PdfViewerWidget].
///
/// Shows a single PDF loaded from a network URL with search enabled. The
/// minimal snippet below illustrates the smallest possible usage; the full
/// page wraps it with an [AppBar] for the demo catalog.
///
/// ```dart
/// PdfViewerWidget(
///   source: PdfSource.uri(Uri.parse('https://example.com/file.pdf')),
///   enableSearch: true,
/// )
/// ```
class PdfViewerWidgetExample extends StatefulWidget {
  /// Creates an instance of [PdfViewerWidgetExample].
  const PdfViewerWidgetExample({super.key});

  @override
  State<PdfViewerWidgetExample> createState() => _PdfViewerWidgetExampleState();
}

class _PdfViewerWidgetExampleState extends State<PdfViewerWidgetExample> {
  bool _enableSearch = true;

  // A ~5 MB public-domain sample, hosted on GitHub raw so it sends CORS and a
  // Content-Length (making the download progress bar determinate) and supports
  // range requests. Large enough that the progress bar is visible while it
  // loads.
  static final Uri _sampleUri = Uri.parse(
    'https://raw.githubusercontent.com/py-pdf/sample-files/main/009-pdflatex-geotopo/GeoTopo.pdf',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Viewer Example'),
        actions: [
          const Text('Search'),
          Switch(
            value: _enableSearch,
            onChanged: (value) => setState(() => _enableSearch = value),
          ),
          const SizedBox(width: 8),
          const BrightnessButton(),
        ],
      ),
      // preferRangeAccess is left false here so pdfrx downloads the whole file
      // before first render, which showcases the determinate download progress
      // bar. Set it to true to instead stream the document via HTTP range
      // requests — the first page then renders after a single small request, so
      // the progress bar barely appears. See the package README for the
      // trade-off.
      //
      // useProgressiveLoading (on by default) hands back pages as the document
      // parses; combined with preferRangeAccess: true it yields true on-demand,
      // page-by-page loading of a large remote PDF.
      body: PdfViewerWidget(
        source: PdfSource.uri(
          _sampleUri,
          preferRangeAccess: false,
          useProgressiveLoading: true,
        ),
        enableSearch: _enableSearch,
        // Open to a specific page (1 = default; e.g. from a deep link) and fail
        // a stalled network load after 30s instead of spinning forever.
        initialPageNumber: 1,
        networkTimeout: const Duration(seconds: 30),
        onDocumentLoaded: (pageCount) => debugPrint('Loaded $pageCount pages'),
        onPageChanged: (page) => debugPrint('On page $page'),
        // The built-in progress bar across the top of the viewer is shown by
        // default; this callback additionally reports raw byte counts.
        onDownloadProgress: (received, total) =>
            debugPrint('Downloaded $received / ${total ?? '?'} bytes'),
        errorBuilder: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load PDF:\n$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}
