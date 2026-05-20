import 'package:codifyiq_core_components/codifyiq_core_components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CodifyChatMessage', () {
    test('value equality and hashCode cover every field', () {
      final createdAt = DateTime(2026, 5, 19, 10);
      final a = CodifyChatMessage(
        id: 'm1',
        sender: CodifyChatSender.user,
        kind: CodifyChatMessageKind.text,
        text: 'hi',
        createdAt: createdAt,
      );
      final b = CodifyChatMessage(
        id: 'm1',
        sender: CodifyChatSender.user,
        kind: CodifyChatMessageKind.text,
        text: 'hi',
        createdAt: createdAt,
      );

      // Distinct instances with identical fields compare equal.
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);

      // Changing any individual field breaks equality.
      expect(a, isNot(a.copyWith(text: 'changed')));
      expect(a, isNot(a.copyWith(seenAt: DateTime(2026, 5, 20))));
      expect(
        a,
        isNot(a.copyWith(sourceUri: Uri.parse('https://example.com/x'))),
      );
      expect(a, isNot(a.copyWith(fileSizeBytes: 99)));
      expect(a, isNot(a.copyWith(sender: CodifyChatSender.ai)));
      expect(a, isNot(a.copyWith(kind: CodifyChatMessageKind.error)));
    });

    test('copyWith with no overrides equals the source', () {
      final original = CodifyChatMessage.ai(
        text: 'hello',
        id: 'm2',
        createdAt: DateTime(2026, 5, 19),
      );
      expect(original.copyWith(), original);
    });
  });
}
