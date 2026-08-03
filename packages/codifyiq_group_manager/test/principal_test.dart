import 'dart:typed_data';

import 'package:codifyiq_group_manager/codifyiq_group_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Principal equality', () {
    test('a photo re-read from a backend leaves the principal equal', () {
      // The load-bearing claim behind "build it inline": two lists holding the
      // same bytes must not read as a change, or every row rebuilds per frame.
      final first = Principal(
        id: 'ada',
        name: 'Ada Lovelace',
        photoBytes: Uint8List.fromList(const [1, 2, 3]),
      );
      final second = Principal(
        id: 'ada',
        name: 'Ada Lovelace',
        photoBytes: Uint8List.fromList(const [1, 2, 3]),
      );
      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('different photo bytes are a change', () {
      final first = Principal(
        id: 'ada',
        name: 'Ada Lovelace',
        photoBytes: Uint8List.fromList(const [1, 2, 3]),
      );
      expect(
        first,
        isNot(
          Principal(
            id: 'ada',
            name: 'Ada Lovelace',
            photoBytes: Uint8List.fromList(const [4, 5, 6]),
          ),
        ),
      );
      // Same length, different content — the hash may collide, but == must not.
      expect(
        first ==
            first.copyWith(photoBytes: Uint8List.fromList(const [9, 9, 9])),
        isFalse,
      );
    });

    test('photoBase64 and imageProvider participate in equality', () {
      const withBase64 = Principal(
        id: 'ada',
        name: 'Ada Lovelace',
        photoBase64: 'aGVsbG8=',
      );
      expect(
        withBase64,
        const Principal(
          id: 'ada',
          name: 'Ada Lovelace',
          photoBase64: 'aGVsbG8=',
        ),
      );
      expect(
        withBase64,
        isNot(const Principal(id: 'ada', name: 'Ada Lovelace')),
      );

      const provider = AssetImage('ada.png');
      expect(
        const Principal(id: 'ada', name: 'Ada', imageProvider: provider),
        const Principal(id: 'ada', name: 'Ada', imageProvider: provider),
      );
    });
  });

  group('Principal.copyWith', () {
    final principal = Principal(
      id: 'ada',
      name: 'Ada Lovelace',
      description: 'ada@example.com',
      imageUrl: 'https://example.com/ada.png',
      photoBytes: Uint8List.fromList(const [1, 2, 3]),
      photoBase64: 'aGVsbG8=',
      imageProvider: const AssetImage('ada.png'),
      icon: Icons.person,
    );

    test('carries every field forward untouched by default', () {
      expect(principal.copyWith(), principal);
    });

    test('each clear flag resets only its own field', () {
      expect(principal.copyWith(clearPhotoBytes: true).photoBytes, isNull);
      expect(principal.copyWith(clearPhotoBytes: true).photoBase64, 'aGVsbG8=');
      expect(principal.copyWith(clearPhotoBase64: true).photoBase64, isNull);
      expect(
        principal.copyWith(clearPhotoBase64: true).photoBytes,
        principal.photoBytes,
      );
      expect(
        principal.copyWith(clearImageProvider: true).imageProvider,
        isNull,
      );
      expect(principal.copyWith(clearImageUrl: true).imageUrl, isNull);
    });
  });
}
