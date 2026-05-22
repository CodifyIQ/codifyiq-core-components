import 'package:codifyiq_core_components/codifyiq_core_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserAvatar.initialsFor', () {
    test('two-word name → first+last initials, uppercased', () {
      expect(UserAvatar.initialsFor(displayName: 'Ada Lovelace'), 'AL');
      expect(UserAvatar.initialsFor(displayName: 'grace hopper'), 'GH');
    });

    test('three-or-more-word name → first+last initials', () {
      expect(
        UserAvatar.initialsFor(displayName: 'Mary Jackson Smith'),
        'MS',
      );
    });

    test('single-word name → first two characters', () {
      expect(UserAvatar.initialsFor(displayName: 'Linus'), 'LI');
    });

    test('single-character single-word name → that character', () {
      expect(UserAvatar.initialsFor(displayName: 'A'), 'A');
    });

    test('name with extra internal whitespace collapses cleanly', () {
      expect(
        UserAvatar.initialsFor(displayName: '  Ada   Lovelace  '),
        'AL',
      );
    });

    test('name starting with a multi-code-unit grapheme stays valid', () {
      // U+1F600 (😀) is a surrogate pair in UTF-16; naive [0] would split it.
      final initials = UserAvatar.initialsFor(displayName: '😀lice Wonder');
      expect(initials.runes.length, 2);
      expect(initials, '😀W');
    });

    test('email used only when displayName is null or blank', () {
      expect(
        UserAvatar.initialsFor(email: 'kathleen.booth@example.com'),
        'KA',
      );
      expect(
        UserAvatar.initialsFor(displayName: '   ', email: 'foo@bar.com'),
        'FO',
      );
    });

    test('single-character email username → that character', () {
      expect(UserAvatar.initialsFor(email: 'a@b.com'), 'A');
    });

    test('email with no username (leading @) → empty', () {
      expect(UserAvatar.initialsFor(email: '@example.com'), '');
    });

    test('null/blank inputs → empty string', () {
      expect(UserAvatar.initialsFor(), '');
      expect(UserAvatar.initialsFor(displayName: '', email: ''), '');
      expect(UserAvatar.initialsFor(displayName: '   '), '');
    });
  });

  group('UserAvatar widget', () {
    Widget pump(Widget child) => MaterialApp(
          home: Scaffold(body: Center(child: child)),
        );

    testWidgets('renders person icon when no identifying info is provided',
        (tester) async {
      await tester.pumpWidget(pump(const UserAvatar()));
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('renders initials when displayName is provided without photo',
        (tester) async {
      await tester.pumpWidget(
        pump(const UserAvatar(displayName: 'Ada Lovelace')),
      );
      expect(find.text('AL'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsNothing);
    });

    testWidgets('uses provided fallbackChild over initials', (tester) async {
      await tester.pumpWidget(
        pump(
          const UserAvatar(
            displayName: 'Ada Lovelace',
            fallbackChild: Icon(Icons.star),
          ),
        ),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('AL'), findsNothing);
    });

    testWidgets('imageProviderBuilder is invoked with the supplied URL',
        (tester) async {
      String? capturedUrl;
      await tester.pumpWidget(
        pump(
          UserAvatar(
            photoUrl: 'https://example.com/a.png',
            displayName: 'Ada Lovelace',
            imageProviderBuilder: (url, headers) {
              capturedUrl = url;
              // Return a 1x1 transparent image provider that never resolves.
              return const AssetImage('__test_never_loads__');
            },
          ),
        ),
      );
      expect(capturedUrl, 'https://example.com/a.png');
    });

    testWidgets('exposes a Semantics label derived from displayName',
        (tester) async {
      await tester.pumpWidget(
        pump(const UserAvatar(displayName: 'Ada Lovelace')),
      );
      expect(find.bySemanticsLabel('Ada Lovelace'), findsOneWidget);
    });

    testWidgets('explicit semanticLabel overrides displayName', (tester) async {
      await tester.pumpWidget(
        pump(
          const UserAvatar(
            displayName: 'Ada Lovelace',
            semanticLabel: 'Profile photo',
          ),
        ),
      );
      expect(find.bySemanticsLabel('Profile photo'), findsOneWidget);
      expect(find.bySemanticsLabel('Ada Lovelace'), findsNothing);
    });

    testWidgets('falls back to "User avatar" when no identifying info exists',
        (tester) async {
      await tester.pumpWidget(pump(const UserAvatar()));
      expect(find.bySemanticsLabel('User avatar'), findsOneWidget);
    });
  });
}
