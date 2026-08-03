import 'dart:typed_data';

import 'package:codifyiq_group_manager/codifyiq_group_manager.dart';
import 'package:codifyiq_user_avatar/codifyiq_user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a [PrincipalAvatar] for [name] and returns the initials it renders, or
/// null when it fell through to the generic person glyph.
Future<String?> _initialsFor(WidgetTester tester, String name) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PrincipalAvatar(
          principal: Principal(id: 'p', name: name),
        ),
      ),
    ),
  );
  final text = find.byType(Text);
  if (text.evaluate().isEmpty) return null;
  return tester.widget<Text>(text).data;
}

/// Call count for [_countingBuilder]. A top-level function is used rather than
/// an inline closure so the builder is a *stable* reference across pumps —
/// a fresh closure per build compares unequal and would refetch the photo.
int _builderCalls = 0;

ImageProvider _countingBuilder(String url, Map<String, String>? headers) {
  _builderCalls++;
  return const AssetImage('cached.png');
}

void main() {
  // Initials are UserAvatar's to derive — the exhaustive matrix (qualifiers,
  // graphemes, email fallback) lives in codifyiq_user_avatar's own tests. What
  // matters here is that a member avatar reads identically to one elsewhere in
  // the app, so these assert the delegation rather than re-testing the rules.
  group('PrincipalAvatar initials', () {
    testWidgets('match UserAvatar.initialsFor for the same name', (
      tester,
    ) async {
      for (final name in [
        'Ada Lovelace',
        'grace hopper',
        'Mary Jackson Smith',
        'Linus',
        'Alice [Contractor]',
        'Java Joe (Contractor)',
        'Ada (PhD) Lovelace',
        '😀lice Wonder',
      ]) {
        expect(
          await _initialsFor(tester, name),
          UserAvatar.initialsFor(displayName: name),
          reason: 'initials for "$name" diverged from UserAvatar',
        );
      }
    });

    testWidgets('a name that is entirely a qualifier falls back to the glyph', (
      tester,
    ) async {
      expect(await _initialsFor(tester, '[Contractor]'), isNull);
      expect(await _initialsFor(tester, '   '), isNull);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('a service account renders its icon instead of initials', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrincipalAvatar(
              principal: Principal(
                id: 'bot',
                name: 'Nightly Sync',
                icon: Icons.smart_toy,
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });
  });

  group('PrincipalAvatar rendering', () {
    testWidgets('delegates to UserAvatar, tinted with the group palette', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrincipalAvatar(
              principal: Principal(id: 'ada', name: 'Ada Lovelace'),
              radius: 24,
            ),
          ),
        ),
      );
      // Photos and initials render through the same widget the rest of the app
      // uses, so a user's avatar cannot look different here than on a members
      // screen.
      final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
      expect(avatar.radius, 24);
      expect(avatar.displayName, 'Ada Lovelace');
      expect(avatar.backgroundColor, isNotNull);
      expect(avatar.foregroundColor, isNotNull);
    });

    testWidgets('standalone, it announces the member it represents', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrincipalAvatar(
              principal: Principal(id: 'ada', name: 'Ada Lovelace'),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Ada Lovelace'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('beside a label that already names the member, it stays silent '
        'rather than announcing the name twice', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrincipalChip(
              principal: Principal(id: 'ada', name: 'Ada Lovelace'),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Ada Lovelace'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('PrincipalAvatar photo loading', () {
    const principal = Principal(
      id: 'ada',
      name: 'Ada Lovelace',
      imageUrl: 'https://example.com/ada.png',
    );

    /// Pumps [avatar] and returns the provider it ended up rendering, or null
    /// when it fell back to initials.
    Future<ImageProvider?> pumpAndReadProvider(
      WidgetTester tester,
      PrincipalAvatar avatar,
    ) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: avatar)));
      final image = find.byType(Image);
      if (image.evaluate().isEmpty) return null;
      return tester.widget<Image>(image).image;
    }

    testWidgets('headers are forwarded to the default NetworkImage', (
      tester,
    ) async {
      const headers = {'Authorization': 'Bearer token'};
      final provider = await pumpAndReadProvider(
        tester,
        const PrincipalAvatar(principal: principal, headers: headers),
      );
      expect(provider, isA<NetworkImage>());
      expect((provider! as NetworkImage).headers, headers);
    });

    testWidgets('imageProviderBuilder receives the URL and headers', (
      tester,
    ) async {
      String? seenUrl;
      Map<String, String>? seenHeaders;
      const headers = {'Authorization': 'Bearer token'};
      final provider = await pumpAndReadProvider(
        tester,
        PrincipalAvatar(
          principal: principal,
          headers: headers,
          imageProviderBuilder: (url, h) {
            seenUrl = url;
            seenHeaders = h;
            return const AssetImage('cached.png');
          },
        ),
      );
      expect(seenUrl, 'https://example.com/ada.png');
      expect(seenHeaders, headers);
      expect(provider, const AssetImage('cached.png'));
    });

    testWidgets('every photo source is forwarded to UserAvatar in precedence '
        'order', (tester) async {
      final bytes = Uint8List.fromList(const [1, 2, 3]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrincipalAvatar(
              principal: Principal(
                id: 'ada',
                name: 'Ada Lovelace',
                imageUrl: 'https://example.com/ada.png',
                photoBytes: bytes,
                photoBase64: 'aGVsbG8=',
              ),
            ),
          ),
        ),
      );
      // Precedence itself is UserAvatar's to enforce — what matters here is
      // that no source is dropped on the floor on the way to it.
      final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
      expect(avatar.photoBytes, bytes);
      expect(avatar.photoBase64, 'aGVsbG8=');
      expect(avatar.photoUrl, 'https://example.com/ada.png');
    });

    testWidgets('a base64 photo renders without the caller decoding it', (
      tester,
    ) async {
      const redPixelPng =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
          'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      final provider = await pumpAndReadProvider(
        tester,
        const PrincipalAvatar(
          principal: Principal(
            id: 'ada',
            name: 'Ada Lovelace',
            photoBase64: redPixelPng,
          ),
        ),
      );
      expect(provider, isA<MemoryImage>());
    });

    testWidgets('Principal.imageProvider wins over the URL and the builder', (
      tester,
    ) async {
      final bytes = Uint8List.fromList(const [1, 2, 3]);
      var builderCalled = false;
      final provider = await pumpAndReadProvider(
        tester,
        PrincipalAvatar(
          principal: Principal(
            id: 'ada',
            name: 'Ada Lovelace',
            imageUrl: 'https://example.com/ada.png',
            imageProvider: MemoryImage(bytes),
          ),
          imageProviderBuilder: (url, headers) {
            builderCalled = true;
            return const AssetImage('cached.png');
          },
        ),
      );
      expect(builderCalled, isFalse);
      expect(provider, isA<MemoryImage>());
      expect((provider! as MemoryImage).bytes, bytes);
    });

    testWidgets('the builder is not called when there is no photo', (
      tester,
    ) async {
      var called = false;
      final provider = await pumpAndReadProvider(
        tester,
        PrincipalAvatar(
          principal: const Principal(id: 'ada', name: 'Ada Lovelace'),
          imageProviderBuilder: (url, headers) {
            called = true;
            return const AssetImage('cached.png');
          },
        ),
      );
      expect(called, isFalse);
      expect(provider, isNull);
    });

    testWidgets('a stable builder is not re-invoked when nothing '
        'photo-related changes', (tester) async {
      _builderCalls = 0;
      Widget build(double radius) => MaterialApp(
        home: Scaffold(
          body: PrincipalAvatar(
            principal: principal,
            radius: radius,
            imageProviderBuilder: _countingBuilder,
          ),
        ),
      );
      await tester.pumpWidget(build(20));
      await tester.pumpWidget(build(24));
      // Only the radius changed, so the photo is not refetched or re-decoded.
      expect(_builderCalls, 1);
    });

    testWidgets('changing headers re-invokes the builder', (tester) async {
      _builderCalls = 0;
      Widget build(Map<String, String> headers) => MaterialApp(
        home: Scaffold(
          body: PrincipalAvatar(
            principal: principal,
            headers: headers,
            imageProviderBuilder: _countingBuilder,
          ),
        ),
      );
      await tester.pumpWidget(build(const {'Authorization': 'Bearer old'}));
      await tester.pumpWidget(build(const {'Authorization': 'Bearer new'}));
      // A refreshed credential must reach the wire, so the fetch is redone.
      expect(_builderCalls, 2);
    });
  });
}
