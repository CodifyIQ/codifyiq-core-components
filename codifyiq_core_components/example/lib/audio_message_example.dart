import 'dart:async';

import 'package:codifyiq_core_components/codifyiq_core_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

/// Throwaway demo screen showing [AudioMessageWidget] integrated with the
/// standard Flyer Chat [Chat] widget.
///
/// Renders a static conversation with mixed text and audio messages.
/// The [Builders.audioMessageBuilder] wires each [AudioMessage.source] to
/// an [AudioMessageWidget] wrapped in a theme-tinted bubble.
class AudioMessageExample extends StatefulWidget {
  /// Creates an [AudioMessageExample].
  const AudioMessageExample({super.key});

  @override
  State<AudioMessageExample> createState() => _AudioMessageExampleState();
}

class _AudioMessageExampleState extends State<AudioMessageExample> {
  static const _meId = 'me';
  static const _themId = 'them';

  static const _me = User(id: _meId, name: 'You');
  static const _them = User(id: _themId, name: 'Alex');

  late final InMemoryChatController _chatController;

  @override
  void initState() {
    super.initState();
    _chatController = InMemoryChatController();

    // setMessages expects oldest-first (index 0 = top, last index = bottom/newest).
    unawaited(_chatController.setMessages([
      const Message.text(
        id: 'msg-1',
        authorId: _themId,
        text: 'Hey! Check out this voice note.',
      ),
      Message.audio(
        id: 'msg-2',
        authorId: _themId,
        source: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        duration: const Duration(minutes: 7, seconds: 13),
        createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
      const Message.text(
        id: 'msg-3',
        authorId: _meId,
        text: "Nice, here's one from my end:",
      ),
      Message.audio(
        id: 'msg-4',
        authorId: _meId,
        source: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        duration: const Duration(minutes: 4, seconds: 8),
        createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
      const Message.text(
        id: 'msg-5',
        authorId: _themId,
        text: '(Broken URL below — tap the error icon to test retry)',
      ),
      Message.audio(
        id: 'msg-6',
        authorId: _themId,
        source: 'https://example.com/does-not-exist.mp3',
        duration: const Duration(seconds: 30),
        createdAt: DateTime.now(),
      ),
    ]));
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<User?> _resolveUser(String id) async => id == _meId ? _me : _them;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Message')),
      body: Chat(
        currentUserId: _meId,
        resolveUser: _resolveUser,
        chatController: _chatController,
        theme: ChatTheme.fromThemeData(Theme.of(context)),
        builders: Builders(
          audioMessageBuilder:
              (context, message, index, {required isSentByMe, groupStatus}) {
                return _AudioBubble(
                  url: message.source,
                  isSentByMe: isSentByMe,
                );
              },
        ),
      ),
    );
  }
}

/// A styled container that wraps [AudioMessageWidget] in a chat bubble.
class _AudioBubble extends StatelessWidget {
  const _AudioBubble({required this.url, required this.isSentByMe});

  final String url;
  final bool isSentByMe;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSentByMe
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: AudioMessageWidget(url: url),
    );
  }
}
