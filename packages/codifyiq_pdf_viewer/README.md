# codifyiq_pdf_viewer

[![pub package](https://img.shields.io/pub/v/codifyiq_pdf_viewer.svg)](https://pub.dev/packages/codifyiq_pdf_viewer)

A reusable PDF viewer backed by [`pdfrx`](https://pub.dev/packages/pdfrx). Renders a document
from a network URI, a local file path, or in-memory bytes via a single `PdfSource` parameter.

```dart
import 'package:codifyiq_pdf_viewer/codifyiq_pdf_viewer.dart';

PdfViewerWidget(
  source: PdfSource.uri(Uri.parse('https://example.com/file.pdf')),
  enableSearch: true,
  onDocumentLoaded: (pageCount) => debugPrint('Loaded $pageCount pages'),
);
```

## What this adds on top of `pdfrx`

* **Built-in search UI** — a Material search bar, debounced input, match counter, and
  next/previous controls that wrap around at both ends.
* **Consistent zoom bounds** — the `minScale` / `maxScale` you pass are honored by pinch,
  +/− buttons, and Ctrl/Cmd + scroll-wheel alike.
* **On-screen web zoom buttons** and a **page indicator overlay**.
* **A unified `PdfSource`** (value-equal variants) in place of `pdfrx`'s separate
  `.uri` / `.file` / `.data` constructors, so swapping documents at runtime diffs cleanly.

## Installation

```yaml
dependencies:
  codifyiq_pdf_viewer: ^1.0.0
```

For PDFs behind an authenticated endpoint, pass HTTP headers via `PdfSource.uri`:

```dart
PdfViewerWidget(
  source: PdfSource.uri(
    Uri.parse('https://api.example.com/documents/42.pdf'),
    headers: {'Authorization': 'Bearer $jwt'},
  ),
);
```

> **Web note:** PDFs loaded via `PdfSource.uri` require the server to send appropriate CORS
> headers. `PdfSource.file` is not supported on the web platform.

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)
