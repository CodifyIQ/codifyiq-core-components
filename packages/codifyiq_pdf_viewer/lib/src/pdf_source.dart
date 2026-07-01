import 'package:flutter/foundation.dart';

/// The source from which a PDF document is loaded.
///
/// Construct one of the concrete variants and hand it to a `PdfViewerWidget`:
///
/// ```dart
/// PdfViewerWidget(source: PdfSource.uri(Uri.parse('https://example.com/file.pdf')))
/// PdfViewerWidget(source: PdfSource.file('/path/to/file.pdf'))
/// PdfViewerWidget(source: PdfSource.bytes(myUint8List))
/// ```
sealed class PdfSource {
  const PdfSource();

  /// Loads a PDF from a network [Uri].
  ///
  /// [headers] are sent with the HTTP request — supply authentication or
  /// authorization headers here (e.g. a JWT bearer token) for endpoints that
  /// require them.
  ///
  /// When [preferRangeAccess] is `true`, the renderer fetches only the byte
  /// ranges needed for the current viewport (via HTTP range requests) instead
  /// of downloading the whole document up front, so the first page of a large
  /// PDF renders after a single small request. The server must respond with
  /// `206 Partial Content`; if it doesn't, the renderer falls back to a full
  /// download automatically, so enabling this is safe even for servers that
  /// don't support ranges. Ignored on web. Defaults to `false`.
  ///
  /// When [useProgressiveLoading] is `true` (the default), the renderer hands
  /// back pages as the document structure resolves instead of waiting for the
  /// whole file to parse, so later pages can render before the download
  /// finishes. Pair it with [preferRangeAccess] for on-demand loading of a
  /// large remote PDF.
  ///
  /// Incremental, page-by-page streaming only works on a **linearized**
  /// ("Fast Web View") PDF. A non-linearized document keeps its cross-reference
  /// table at the end of the file, so pages past the first can't resolve until
  /// nearly the whole file has downloaded, even with [preferRangeAccess]. See
  /// the package README for how to linearize.
  ///
  /// On web, the target server must serve appropriate CORS headers.
  const factory PdfSource.uri(
    Uri uri, {
    Map<String, String>? headers,
    bool preferRangeAccess,
    bool useProgressiveLoading,
  }) = PdfUriSource;

  /// Loads a PDF from a local file path. Not supported on web.
  const factory PdfSource.file(String path) = PdfFileSource;

  /// Loads a PDF from raw bytes already in memory.
  ///
  /// [sourceName] is an optional identifier used by the underlying renderer
  /// for caching and error messages; defaults to `document.pdf`.
  const factory PdfSource.bytes(Uint8List bytes, {String? sourceName}) =
      PdfBytesSource;
}

/// A [PdfSource] backed by a network [Uri].
final class PdfUriSource extends PdfSource {
  /// Creates a [PdfUriSource] that loads from [uri].
  ///
  /// [headers] are sent with the HTTP request — use this to supply
  /// authentication/authorization headers (e.g. a JWT bearer token).
  ///
  /// When [preferRangeAccess] is `true`, the renderer streams the document via
  /// HTTP range requests instead of downloading it in full up front. When
  /// [useProgressiveLoading] is `true` (the default), pages resolve as the
  /// document parses rather than only after the whole file is available. See
  /// [PdfSource.uri] for details. Both are ignored on web.
  const PdfUriSource(
    this.uri, {
    this.headers,
    this.preferRangeAccess = false,
    this.useProgressiveLoading = true,
  });

  /// The URI to fetch the PDF from.
  final Uri uri;

  /// Optional HTTP headers sent with the request, e.g. for authentication.
  final Map<String, String>? headers;

  /// Whether to fetch the document on demand via HTTP range requests rather
  /// than downloading it in full before rendering. No effect on web.
  final bool preferRangeAccess;

  /// Whether pages are handed back progressively as the document parses,
  /// instead of only once the full structure has resolved. Defaults to `true`.
  /// No effect on web.
  final bool useProgressiveLoading;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PdfUriSource &&
          other.uri == uri &&
          mapEquals(other.headers, headers) &&
          other.preferRangeAccess == preferRangeAccess &&
          other.useProgressiveLoading == useProgressiveLoading);

  @override
  int get hashCode => Object.hash(
    uri,
    headers == null
        ? null
        : Object.hashAllUnordered(
            headers!.entries.map((e) => Object.hash(e.key, e.value)),
          ),
    preferRangeAccess,
    useProgressiveLoading,
  );
}

/// A [PdfSource] backed by a local file path.
final class PdfFileSource extends PdfSource {
  /// Creates a [PdfFileSource] that reads from [path].
  const PdfFileSource(this.path);

  /// The absolute or relative file path of the PDF.
  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PdfFileSource && other.path == path);

  @override
  int get hashCode => path.hashCode;
}

/// A [PdfSource] backed by in-memory bytes.
final class PdfBytesSource extends PdfSource {
  /// Creates a [PdfBytesSource] from [bytes].
  const PdfBytesSource(this.bytes, {this.sourceName});

  /// The raw PDF bytes.
  final Uint8List bytes;

  /// Optional identifier used for caching and diagnostics.
  final String? sourceName;

  // Bytes are compared by identity rather than content: equating two large
  // buffers byte-for-byte would be O(n) and the common consumer pattern is
  // to hold a stable Uint8List reference per document. Callers that want a
  // reload should pass a new Uint8List.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PdfBytesSource &&
          identical(other.bytes, bytes) &&
          other.sourceName == sourceName);

  @override
  int get hashCode => Object.hash(identityHashCode(bytes), sourceName);
}
