# codifyiq_pdf_viewer example

```dart
import 'package:codifyiq_pdf_viewer/codifyiq_pdf_viewer.dart';
import 'package:flutter/material.dart';

Widget buildViewer() {
  return PdfViewerWidget(
    source: PdfSource.uri(Uri.parse('https://example.com/file.pdf')),
    enableSearch: true,
    onDocumentLoaded: (pageCount) => debugPrint('Loaded $pageCount pages'),
  );
}
```

A runnable catalog demonstrating every CodifyIQ component lives in the
[`example/` app at the repository root](https://github.com/CodifyIQ/codifyiq-core-components/tree/dev/example).
