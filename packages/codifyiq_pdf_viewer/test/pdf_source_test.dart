import 'dart:typed_data';

import 'package:codifyiq_pdf_viewer/codifyiq_pdf_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // PdfSource equality is load-bearing: PdfViewerWidget only reloads the
  // document when the new source is unequal to the old one. These tests pin
  // that contract so a regression in == / hashCode (e.g. dropping a field)
  // that would silently stop reloads gets caught here.
  final uri = Uri.parse('https://example.com/doc.pdf');
  final otherUri = Uri.parse('https://example.com/other.pdf');

  group('PdfUriSource equality', () {
    test('equal for the same uri and defaults', () {
      expect(PdfSource.uri(uri), PdfSource.uri(uri));
      expect(PdfSource.uri(uri).hashCode, PdfSource.uri(uri).hashCode);
    });

    test('unequal when the uri differs', () {
      expect(PdfSource.uri(uri), isNot(PdfSource.uri(otherUri)));
    });

    test('unequal when preferRangeAccess differs', () {
      expect(
        PdfSource.uri(uri, preferRangeAccess: true),
        isNot(PdfSource.uri(uri)),
      );
    });

    test('unequal when useProgressiveLoading differs', () {
      // Default is true, so an explicit false must not compare equal.
      expect(
        PdfSource.uri(uri, useProgressiveLoading: false),
        isNot(PdfSource.uri(uri)),
      );
    });

    test('equality reflects header contents, not map identity', () {
      expect(
        PdfSource.uri(uri, headers: {'Authorization': 'Bearer a'}),
        PdfSource.uri(uri, headers: {'Authorization': 'Bearer a'}),
      );
      expect(
        PdfSource.uri(uri, headers: {'Authorization': 'Bearer a'}),
        isNot(PdfSource.uri(uri, headers: {'Authorization': 'Bearer b'})),
      );
    });
  });

  group('PdfFileSource / PdfBytesSource equality', () {
    test('files compare by path', () {
      expect(PdfSource.file('/a.pdf'), PdfSource.file('/a.pdf'));
      expect(PdfSource.file('/a.pdf'), isNot(PdfSource.file('/b.pdf')));
    });

    test('bytes compare by identity, not content', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(PdfSource.bytes(bytes), PdfSource.bytes(bytes));
      // A distinct buffer with identical content is intentionally unequal so
      // callers can force a reload by passing a fresh Uint8List.
      expect(
        PdfSource.bytes(bytes),
        isNot(PdfSource.bytes(Uint8List.fromList([1, 2, 3]))),
      );
    });
  });
}
