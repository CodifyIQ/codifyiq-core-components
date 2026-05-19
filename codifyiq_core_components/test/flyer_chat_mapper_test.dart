import 'package:codifyiq_core_components/codifyiq_core_components.dart';
import 'package:codifyiq_core_components/widgets/ai_chat/flyer_chat_mapper.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toFlyerMessage', () {
    test('text message maps to a Flyer TextMessage', () {
      final flyer = toFlyerMessage(CodifyChatMessage.ai(text: 'hello'));

      expect(flyer, isA<types.TextMessage>());
      expect((flyer as types.TextMessage).text, 'hello');
    });

    test('image with a sourceUri maps to a Flyer ImageMessage', () {
      final flyer = toFlyerMessage(
        CodifyChatMessage.image(
          text: 'photo.png',
          sourceUri: Uri.parse('https://example.com/photo.png'),
        ),
      );

      expect(flyer, isA<types.ImageMessage>());
      final image = flyer as types.ImageMessage;
      expect(image.uri, 'https://example.com/photo.png');
      expect(image.name, 'photo.png');
    });

    test('image without a sourceUri falls back to a CustomMessage', () {
      final flyer = toFlyerMessage(CodifyChatMessage.image());

      expect(flyer, isA<types.CustomMessage>());
    });

    test('pdf with a sourceUri maps to a Flyer FileMessage', () {
      final flyer = toFlyerMessage(
        CodifyChatMessage.pdf(
          text: 'report.pdf',
          sourceUri: Uri.parse('https://example.com/report.pdf'),
          fileSizeBytes: 2048,
        ),
      );

      expect(flyer, isA<types.FileMessage>());
      final file = flyer as types.FileMessage;
      expect(file.uri, 'https://example.com/report.pdf');
      expect(file.name, 'report.pdf');
      expect(file.size, 2048);
      expect(file.mimeType, 'application/pdf');
    });

    test('pdf without a sourceUri falls back to a CustomMessage', () {
      expect(
        toFlyerMessage(CodifyChatMessage.pdf(text: 'report.pdf')),
        isA<types.CustomMessage>(),
      );
    });

    test('error messages map to a CustomMessage', () {
      expect(
        toFlyerMessage(CodifyChatMessage.error(text: 'failed')),
        isA<types.CustomMessage>(),
      );
    });

    test('user and ai messages get distinct Flyer authors', () {
      final user = toFlyerMessage(CodifyChatMessage.user(text: 'hi'));
      final ai = toFlyerMessage(CodifyChatMessage.ai(text: 'hello'));

      expect(user.author.id, userAuthor.id);
      expect(ai.author.id, aiAuthor.id);
    });
  });

  group('toFlyerMessages', () {
    test('reverses the timeline to the newest-first order Flyer expects', () {
      final timeline = [
        CodifyChatMessage.user(text: 'first', id: 'a'),
        CodifyChatMessage.ai(text: 'second', id: 'b'),
      ];

      final flyer = toFlyerMessages(timeline);

      expect(flyer.map((m) => m.id), ['b', 'a']);
    });
  });
}
