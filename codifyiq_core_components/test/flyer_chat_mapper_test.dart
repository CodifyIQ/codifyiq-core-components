import 'package:codifyiq_core_components/codifyiq_core_components.dart';
import 'package:codifyiq_core_components/widgets/ai_chat/flyer_chat_mapper.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toFlyerMessage', () {
    test('text message maps to a Flyer TextMessage', () {
      final flyer = toFlyerMessage(CodifyChatMessage.ai(text: 'hello'));

      expect(flyer, isA<TextMessage>());
      expect((flyer as TextMessage).text, 'hello');
    });

    test('image with a sourceUri maps to a Flyer ImageMessage', () {
      final flyer = toFlyerMessage(
        CodifyChatMessage.image(
          text: 'photo.png',
          sourceUri: Uri.parse('https://example.com/photo.png'),
        ),
      );

      expect(flyer, isA<ImageMessage>());
      expect((flyer as ImageMessage).source, 'https://example.com/photo.png');
    });

    test('image without a sourceUri falls back to a CustomMessage', () {
      expect(toFlyerMessage(CodifyChatMessage.image()), isA<CustomMessage>());
    });

    test('pdf with a sourceUri maps to a Flyer FileMessage', () {
      final flyer = toFlyerMessage(
        CodifyChatMessage.pdf(
          text: 'report.pdf',
          sourceUri: Uri.parse('https://example.com/report.pdf'),
          fileSizeBytes: 2048,
        ),
      );

      expect(flyer, isA<FileMessage>());
      final file = flyer as FileMessage;
      expect(file.source, 'https://example.com/report.pdf');
      expect(file.name, 'report.pdf');
      expect(file.size, 2048);
      expect(file.mimeType, 'application/pdf');
    });

    test('pdf with an unknown fileSizeBytes maps size to null', () {
      final flyer = toFlyerMessage(
        CodifyChatMessage.pdf(
          text: 'report.pdf',
          sourceUri: Uri.parse('https://example.com/report.pdf'),
          // fileSizeBytes defaults to 0 == unknown.
        ),
      );

      expect((flyer as FileMessage).size, isNull);
    });

    test('pdf without a sourceUri falls back to a CustomMessage', () {
      expect(
        toFlyerMessage(CodifyChatMessage.pdf(text: 'report.pdf')),
        isA<CustomMessage>(),
      );
    });

    test('error messages map to a CustomMessage', () {
      expect(
        toFlyerMessage(CodifyChatMessage.error(text: 'failed')),
        isA<CustomMessage>(),
      );
    });

    test('user and ai messages get distinct Flyer author ids', () {
      final user = toFlyerMessage(CodifyChatMessage.user(text: 'hi'));
      final ai = toFlyerMessage(CodifyChatMessage.ai(text: 'hello'));

      expect(user.authorId, userAuthorId);
      expect(ai.authorId, aiAuthorId);
      expect(userAuthorId, isNot(aiAuthorId));
    });

    test('createdAt and seenAt are carried onto the Flyer message', () {
      final created = DateTime(2026, 5, 19, 10);
      final seen = DateTime(2026, 5, 19, 11);
      final flyer = toFlyerMessage(
        CodifyChatMessage.ai(text: 'hi', createdAt: created, seenAt: seen),
      );

      expect(flyer.createdAt, created);
      expect(flyer.seenAt, seen);
    });
  });

  group('resolveCodifyChatUser', () {
    test('resolves the known author ids and null for anything else', () async {
      expect((await resolveCodifyChatUser(userAuthorId))?.id, userAuthorId);
      expect((await resolveCodifyChatUser(aiAuthorId))?.id, aiAuthorId);
      expect(await resolveCodifyChatUser('someone-else'), isNull);
    });
  });
}
