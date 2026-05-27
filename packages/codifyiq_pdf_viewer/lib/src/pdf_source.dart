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
  /// On web, the target server must serve appropriate CORS headers.
  const factory PdfSource.uri(Uri uri, {Map<String, String>? headers}) =
      PdfUriSource;

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
  const PdfUriSource(this.uri, {this.headers});

  /// The URI to fetch the PDF from.
  final Uri uri;

  /// Optional HTTP headers sent with the request, e.g. for authentication.
  final Map<String, String>? headers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PdfUriSource &&
          other.uri == uri &&
          mapEquals(other.headers, headers));

  @override
  int get hashCode => Object.hash(
    uri,
    headers == null
        ? null
        : Object.hashAllUnordered(
            headers!.entries.map((e) => Object.hash(e.key, e.value)),
          ),
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
