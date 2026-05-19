import 'package:flutter/foundation.dart';

import 'codify_chat_message.dart';

/// Performs the backend round-trip for a chat turn.
///
/// Given the user's [prompt], returns the AI's reply as a [CodifyChatMessage]
/// — typically [CodifyChatMessage.ai] for text, but may also be a
/// [CodifyChatMessage.pdf] or [CodifyChatMessage.image] placeholder. Throwing
/// from the responder makes [AiChatController] append an error bubble.
///
/// The package ships no networking layer: consumers wire the responder to
/// their own API client, SDK, or mock.
typedef AiChatResponder = Future<CodifyChatMessage> Function(String prompt);

/// State manager for an AI chat conversation.
///
/// Owns the ordered message timeline and the request lifecycle for a single
/// chat. `AiChatScreen` listens to this controller and rebuilds when it
/// changes; the controller is otherwise UI-agnostic.
///
/// Typical flow:
///
/// 1. [sendText] appends the user's message, flips [isResponding] on, and
///    awaits the injected [AiChatResponder].
/// 2. On success the responder's message is appended; on failure an error
///    bubble is appended instead.
/// 3. [markSeen] stamps a message's `seenAt` the first time it becomes
///    visible — `AiChatScreen` calls this from Flyer Chat's visibility
///    callback.
///
/// Pass a custom [clock] to override [DateTime.now] in tests.
class AiChatController extends ChangeNotifier {
  /// Creates a controller backed by [responder].
  ///
  /// [initialMessages] seeds the timeline (e.g. a greeting). [clock] overrides
  /// the timestamp source for [sendText] and [markSeen].
  AiChatController({
    required AiChatResponder responder,
    List<CodifyChatMessage>? initialMessages,
    DateTime Function()? clock,
  }) : _responder = responder,
       _clock = clock ?? DateTime.now,
       _messages = List<CodifyChatMessage>.of(
         initialMessages ?? const <CodifyChatMessage>[],
       ) {
    for (final message in _messages) {
      _messagesById[message.id] = message;
    }
  }

  final AiChatResponder _responder;
  final DateTime Function() _clock;
  final List<CodifyChatMessage> _messages;
  // Id index kept in sync with [_messages] so [messageById] is O(1); it is
  // called once per custom-message bubble on every rebuild.
  final Map<String, CodifyChatMessage> _messagesById =
      <String, CodifyChatMessage>{};
  bool _isResponding = false;
  bool _isDisposed = false;

  /// The conversation timeline, oldest first. Unmodifiable.
  List<CodifyChatMessage> get messages => List.unmodifiable(_messages);

  /// Whether a backend request is currently in flight. While `true`,
  /// `AiChatScreen` shows the loading indicator and ignores further sends.
  bool get isResponding => _isResponding;

  /// Whether the timeline has no messages.
  bool get isEmpty => _messages.isEmpty;

  /// Looks up a message by [id], or returns `null` if absent.
  CodifyChatMessage? messageById(String id) => _messagesById[id];

  /// Sends [text] as a user message and requests an AI reply.
  ///
  /// Blank input is ignored, as are sends issued while a request is already
  /// [isResponding]. Listeners are notified when the user message is appended,
  /// and again when the response (or error bubble) arrives.
  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isResponding) return;

    _appendMessage(CodifyChatMessage.user(text: trimmed, createdAt: _clock()));
    _isResponding = true;
    notifyListeners();

    CodifyChatMessage reply;
    try {
      reply = await _responder(trimmed);
    } catch (error, stackTrace) {
      // Surface the failure to the developer (console / FlutterError.onError /
      // crash reporters) — the catch must not swallow it silently — then show
      // the user a generic error bubble.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'codifyiq_core_components',
          context: ErrorDescription('while awaiting an AiChatResponder reply'),
        ),
      );
      reply = CodifyChatMessage.error(
        text: 'Something went wrong. Please try again.',
      );
    }

    // The controller may have been disposed while the responder was in flight
    // (e.g. the user navigated away). Bail before mutating or notifying — a
    // notifyListeners() after dispose() throws.
    if (_isDisposed) return;
    // Stamp the reply on the controller's clock so the whole timeline shares
    // one time source (and honours an injected test clock).
    _appendMessage(reply.copyWith(createdAt: _clock()));
    _isResponding = false;
    notifyListeners();
  }

  /// Appends [message] to the timeline directly, without a backend round-trip.
  ///
  /// Useful for seeding the conversation or injecting messages from another
  /// source.
  void addMessage(CodifyChatMessage message) {
    _appendMessage(message);
    notifyListeners();
  }

  /// Stamps `seenAt` on the message with [id] the first time it is seen.
  ///
  /// No-op when the message is absent or already seen, so it is safe to call
  /// repeatedly from a visibility callback.
  void markSeen(String id) {
    // Visibility callbacks can arrive after the controller is disposed.
    if (_isDisposed) return;
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1 || _messages[index].seenAt != null) return;
    final updated = _messages[index].copyWith(seenAt: _clock());
    _messages[index] = updated;
    _messagesById[updated.id] = updated;
    notifyListeners();
  }

  /// Removes every message from the timeline.
  void clear() {
    if (_messages.isEmpty) return;
    _messages.clear();
    _messagesById.clear();
    notifyListeners();
  }

  /// Appends [message] to the timeline and keeps the id index in sync.
  void _appendMessage(CodifyChatMessage message) {
    _messages.add(message);
    _messagesById[message.id] = message;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
