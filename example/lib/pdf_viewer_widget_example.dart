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

  static final Uri _sampleUri = Uri.parse(
    'https://raw.githubusercontent.com/mozilla/pdf.js/master/test/pdfs/tracemonkey.pdf',
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
        ],
      ),
      body: PdfViewerWidget(
        source: PdfSource.uri(_sampleUri),
        enableSearch: _enableSearch,
        onDocumentLoaded: (pageCount) => debugPrint('Loaded $pageCount pages'),
        onPageChanged: (page) => debugPrint('On page $page'),
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
