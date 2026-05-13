/// Backend integration contract for [ChatWidget].
///
/// Consumers implement [ChatBackend] to wire the widget into their own
/// chat service — whether that's a REST API, a streaming agent endpoint,
/// a local LLM, or anything else. The widget owns all UI state (message
/// list, suggestions, sending/error indicators); the backend is only
/// responsible for producing greetings and turn responses.
library;

/// Backend integration for [ChatWidget].
///
/// Implementations should be cheap to construct — the widget calls
/// [start] once during `initState` and [sendMessage] for each user turn.
abstract class ChatBackend {
  /// Called once when the chat first opens.
  ///
  /// Should return the initial agent greeting and any starter suggestion
  /// chips to display under the composer.
  Future<ChatStartResult> start();

  /// Sends a user [message] and returns the agent's reply.
  Future<ChatTurnResult> sendMessage(String message);
}

/// Result returned by [ChatBackend.start].
class ChatStartResult {
  /// Creates a [ChatStartResult].
  ///
  /// [greeting] is shown as the first agent message. [suggestions] are
  /// rendered as tappable chips beneath the composer.
  const ChatStartResult({required this.greeting, this.suggestions = const []});

  /// The initial agent message displayed when the chat opens.
  final String greeting;

  /// Tappable starter suggestions shown beneath the composer.
  final List<String> suggestions;
}

/// Result returned by [ChatBackend.sendMessage].
class ChatTurnResult {
  /// Creates a [ChatTurnResult].
  const ChatTurnResult({
    required this.response,
    this.suggestions = const [],
    this.hadMutations = false,
  });

  /// The agent's reply to the user's message.
  final String response;

  /// Follow-up suggestion chips to render beneath the composer.
  final List<String> suggestions;

  /// Whether this turn caused side effects the host app should react to
  /// (e.g., entity updates). When `true`, [ChatWidget] invokes its
  /// `onMutations` callback so the host can refresh dependent state.
  final bool hadMutations;
}
