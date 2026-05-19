import 'dart:async';

import 'package:codifyiq_core_components/codifyiq_core_components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiChatController', () {
    test('sendText appends the user message then the AI reply', () async {
      final controller = AiChatController(
        responder: (prompt) async => CodifyChatMessage.ai(text: 'reply'),
      );

      await controller.sendText('hello');

      expect(controller.messages, hasLength(2));
      expect(controller.messages[0].sender, CodifyChatSender.user);
      expect(controller.messages[0].text, 'hello');
      expect(controller.messages[1].sender, CodifyChatSender.ai);
      expect(controller.messages[1].text, 'reply');
    });

    test('sendText trims whitespace and ignores blank input', () async {
      final controller = AiChatController(
        responder: (prompt) async => CodifyChatMessage.ai(text: 'reply'),
      );

      await controller.sendText('   ');
      expect(controller.messages, isEmpty);

      await controller.sendText('  spaced  ');
      expect(controller.messages.first.text, 'spaced');
    });

    test('isResponding is true while awaiting and false afterwards', () async {
      final completer = Completer<CodifyChatMessage>();
      final controller = AiChatController(
        responder: (prompt) => completer.future,
      );

      expect(controller.isResponding, isFalse);

      final pending = controller.sendText('hello');
      expect(controller.isResponding, isTrue);

      completer.complete(CodifyChatMessage.ai(text: 'reply'));
      await pending;
      expect(controller.isResponding, isFalse);
    });

    test('a throwing responder appends an error bubble and reports the '
        'underlying error', () async {
      final reported = <Object>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) => reported.add(details.exception);
      addTearDown(() => FlutterError.onError = previousOnError);

      final controller = AiChatController(
        responder: (prompt) async => throw Exception('backend down'),
      );

      await controller.sendText('hello');

      expect(controller.messages, hasLength(2));
      final last = controller.messages.last;
      expect(last.kind, CodifyChatMessageKind.error);
      expect(last.sender, CodifyChatSender.ai);
      // The responder's exception is surfaced, not silently swallowed.
      expect(reported, hasLength(1));
      expect(reported.single, isA<Exception>());
    });

    test('disposing mid-response does not notify after dispose', () async {
      final completer = Completer<CodifyChatMessage>();
      final controller = AiChatController(
        responder: (prompt) => completer.future,
      );

      final pending = controller.sendText('hello');
      controller.dispose(); // user navigates away while the reply is in flight
      completer.complete(CodifyChatMessage.ai(text: 'reply'));

      // sendText must bail instead of calling notifyListeners() on a disposed
      // controller, which would throw a "used after dispose" assertion.
      await expectLater(pending, completes);
    });

    test('sendText is ignored while a request is in flight', () async {
      final completer = Completer<CodifyChatMessage>();
      final controller = AiChatController(
        responder: (prompt) => completer.future,
      );

      final pending = controller.sendText('first');
      await controller.sendText('second');

      // Only the first user message is present; the second send was dropped.
      expect(controller.messages.where((m) => m.isFromUser), hasLength(1));

      completer.complete(CodifyChatMessage.ai(text: 'reply'));
      await pending;
    });

    test('markSeen stamps seenAt once using the injected clock', () {
      final seenTime = DateTime(2026, 5, 18, 9, 30);
      final controller = AiChatController(
        responder: (prompt) async => CodifyChatMessage.ai(text: 'reply'),
        initialMessages: [CodifyChatMessage.ai(text: 'hi', id: 'm1')],
        clock: () => seenTime,
      );

      expect(controller.messageById('m1')!.isSeen, isFalse);

      controller.markSeen('m1');
      expect(controller.messageById('m1')!.seenAt, seenTime);

      // Idempotent: a second call does not move the timestamp.
      controller.markSeen('m1');
      expect(controller.messageById('m1')!.seenAt, seenTime);
    });

    test('markSeen is a no-op for an unknown id', () {
      final controller = AiChatController(
        responder: (prompt) async => CodifyChatMessage.ai(text: 'reply'),
      );

      controller.markSeen('does-not-exist');
      expect(controller.messages, isEmpty);
    });

    test('addMessage appends directly without a backend round-trip', () {
      final controller = AiChatController(
        responder: (prompt) async => CodifyChatMessage.ai(text: 'reply'),
      );

      controller.addMessage(CodifyChatMessage.pdf(text: 'report.pdf'));

      expect(controller.messages, hasLength(1));
      expect(controller.messages.single.kind, CodifyChatMessageKind.pdf);
    });
  });
}
