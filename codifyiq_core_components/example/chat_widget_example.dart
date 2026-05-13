import 'package:codifyiq_core_components/widgets/chat_backend.dart';
import 'package:codifyiq_core_components/widgets/chat_widget.dart';
import 'package:flutter/material.dart';

/// Demo screen for [ChatWidget] backed by an in-memory echo agent.
///
/// The example shows how a host plugs its own service into the widget
/// by implementing [ChatBackend]. The widget owns the UI; the backend
/// just answers turns.
class ChatWidgetExample extends StatelessWidget {
  /// Creates a [ChatWidgetExample].
  const ChatWidgetExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat Widget Example')),
      body: ChatWidget(
        backend: _EchoBackend(),
        agentUserName: 'Echo',
        composerHint: 'Say something...',
      ),
    );
  }
}

/// A trivial [ChatBackend] that echoes the user's message back with a
/// brief preamble. Intended only for the demo.
class _EchoBackend implements ChatBackend {
  int _turn = 0;

  @override
  Future<ChatStartResult> start() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const ChatStartResult(
      greeting: 'Hi! I echo whatever you say. Try a suggestion below.',
      suggestions: ['Hello there', 'Tell me a joke', 'What can you do?'],
    );
  }

  @override
  Future<ChatTurnResult> sendMessage(String message) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _turn++;
    return ChatTurnResult(
      response: 'You said: "$message"',
      suggestions: _turn.isEven
          ? const ['Tell me more', 'Try again', 'Different question']
          : const [],
    );
  }
}
