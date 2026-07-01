## 1.1.0

* `PdfSource.uri` gains a `preferRangeAccess` flag (default `false`). When enabled, the viewer streams a network PDF via HTTP range requests instead of downloading it in full first, so the first page of a large document renders after a single small request. Servers that don't support range requests fall back to a full download automatically. No effect on web.
* `PdfViewerWidget` now shows a linear download progress bar across the top of the viewer while a network PDF loads — determinate when the server reports a content length, indeterminate otherwise. Disable it with `showDownloadProgress: false`, and/or pass `onDownloadProgress: (received, total) { ... }` to drive your own progress UI.
* `PdfSource.uri` gains a `useProgressiveLoading` flag (default `true`) that hands back pages as the document parses instead of only after the whole file is available. Combined with `preferRangeAccess: true` and a linearized ("Fast Web View") PDF, later pages of a large remote document can render before the download finishes; non-linearized PDFs still need a near-complete download first.
* `PdfViewerWidget` gains an `initialPageNumber` (default `1`) to open a document to a specific page — handy for deep links or resuming where the reader left off. Applies to all source types.
* `PdfViewerWidget` gains a `networkTimeout` (default 30 seconds) for `PdfSource.uri`: if a network request fails to start responding within the window it surfaces the error UI instead of waiting forever. It bounds the response start (connect + headers) per request, not the total download time.

## 1.0.0

* Initial release as a standalone package, extracted from `codifyiq_core_components`.
* `PdfViewerWidget` and `PdfSource` — a PDF viewer with a built-in search UI, consistent zoom bounds, web zoom buttons, a page indicator, and a unified network/file/bytes source.
