import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'codify_chat_message.dart';
import 'flyer_chat_mapper.dart';

/// Performs the backend round-trip for a chat turn.
///
/// Given the user's [prompt], returns the AI's reply as a [CodifyChatMessage]
/// — typically [CodifyChatMessage.ai] for text, but may also be a
/// [CodifyChatMessage.pdf] or [CodifyChatMessage.image]. Throwing from the
/// responder makes [AiChatController] append an error bubble.
///
/// The package ships no networking layer: consumers wire the responder to
/// their own API client, SDK, or mock.
typedef AiChatResponder = Future<CodifyChatMessage> Function(String prompt);

/// State manager for an AI chat conversation.
///
/// Owns the ordered message timeline and the request lifecycle for a single
/// chat. It keeps a Flyer Chat [ChatController] ([chatController]) in sync with
/// the timeline so `AiChatScreen` can hand it straight to the Flyer `Chat`
/// widget; the controller is otherwise UI-agnostic.
///
/// Typical flow:
///
/// 1. [sendText] appends the user's message, flips [isResponding] on, and
///    awaits the injected [AiChatResponder].
/// 2. On success the responder's message is appended; on failure an error
///    bubble is appended instead.
/// 3. [markSeen] stamps a message's `seenAt` the first time it becomes
///    visible — `AiChatScreen` calls this from a visibility callback.
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
       ),
       chatController = InMemoryChatController(
         messages: (initialMessages ?? const <CodifyChatMessage>[])
             .map(toFlyerMessage)
             .toList(),
       ) {
    for (final message in _messages) {
      _messagesById[message.id] = message;
    }
  }

  final AiChatResponder _responder;
  final DateTime Function() _clock;
  final List<CodifyChatMessage> _messages;
  // Id index kept in sync with [_messages] so lookups by id ([messageById],
  // [markSeen]) are O(1) rather than a linear scan.
  final Map<String, CodifyChatMessage> _messagesById =
      <String, CodifyChatMessage>{};
  // Cached unmodifiable view of [_messages], rebuilt lazily after a mutation.
  List<CodifyChatMessage>? _cachedMessages;
  bool _isResponding = false;
  bool _isDisposed = false;
  // Bumped by [clear]. A [sendText] whose responder was in flight when the
  // conversation was cleared compares against this and drops its stale reply.
  int _generation = 0;

  /// The Flyer Chat controller mirroring this timeline.
  ///
  /// Exposed so `AiChatScreen` can pass it to the Flyer `Chat` widget;
  /// consumers drive the chat through [sendText] / [addMessage] and do not
  /// touch this directly. Kept in sync by every mutation below.
  ///
  /// The mutation methods call `insertMessage` / `updateMessage` /
  /// `setMessages` without `await`. [InMemoryChatController] runs those
  /// synchronously (no real `await` in their bodies), so call order is
  /// preserved; swapping in a different [ChatController] implementation
  /// would need re-verifying.
  @internal
  final ChatController chatController;

  /// The conversation timeline, oldest first. Unmodifiable.
  ///
  /// The view is cached and reused until the next mutation, so repeated reads
  /// do not each allocate a copy.
  List<CodifyChatMessage> get messages =>
      _cachedMessages ??= List.unmodifiable(_messages);

  /// Whether a backend request is currently in flight. While `true`,
  /// `AiChatScreen` shows the loading indicator and blocks further sends.
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

    final generation = _generation;
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

    // Bail if, while the responder was in flight, the controller was disposed
    // (e.g. the user navigated away) or the conversation was cleared — the
    // reply is stale either way. A notifyListeners() after dispose() throws.
    if (_isDisposed || generation != _generation) return;
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
    // O(1) lookup + early-out: most visibility ticks are no-ops because the
    // message is absent or already seen.
    final current = _messagesById[id];
    if (current == null || current.seenAt != null) return;
    // Only a genuine first-seen reaches here; locating the list slot for the
    // in-place update is O(n), but runs at most once per message.
    final index = _messages.indexOf(current);
    if (index == -1) return;
    final updated = current.copyWith(seenAt: _clock());
    _messages[index] = updated;
    _messagesById[id] = updated;
    _cachedMessages = null;
    chatController.updateMessage(
      toFlyerMessage(current),
      toFlyerMessage(updated),
    );
    notifyListeners();
  }

  /// Removes every message from the timeline.
  ///
  /// If a reply is in flight it is abandoned: [isResponding] is reset now and
  /// the late reply is dropped on arrival rather than appended to the emptied
  /// timeline.
  void clear() {
    if (_messages.isEmpty && !_isResponding) return;
    _messages.clear();
    _messagesById.clear();
    _cachedMessages = null;
    _isResponding = false;
    _generation++;
    chatController.setMessages(const <Message>[]);
    notifyListeners();
  }

  /// Appends [message] to the timeline, the id index, and the Flyer controller.
  void _appendMessage(CodifyChatMessage message) {
    _messages.add(message);
    _messagesById[message.id] = message;
    _cachedMessages = null;
    chatController.insertMessage(toFlyerMessage(message));
  }

  @override
  void dispose() {
    _isDisposed = true;
    chatController.dispose();
    super.dispose();
  }
}
