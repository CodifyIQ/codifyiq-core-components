import 'dart:async';

import 'package:cross_cache/cross_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';

import 'chat_backend.dart';

/// A reusable conversational chat widget backed by [flutter_chat_ui].
///
/// [ChatWidget] renders a message list, optional error banner, suggestion
/// chips, and a composer. It is backend-agnostic: callers supply a
/// [ChatBackend] implementation that produces the initial greeting and
/// responds to each user turn. All UI state (messages, suggestions,
/// sending/error indicators) is owned by the widget.
///
/// The widget intentionally does not provide its own scaffolding (drag
/// handle, title, etc.) so it composes cleanly inside a [Scaffold],
/// modal bottom sheet, dialog, or any other container chosen by the host.
///
/// ## Identifiers and naming
///
/// Messages are tagged with [currentUserId] (default `'user'`) for the
/// human and [agentUserId] (default `'agent'`) for the assistant. The
/// display names rendered by Flyer Chat are [currentUserName] and
/// [agentUserName].
///
/// ## Pre-seeding the conversation
///
/// Pass [initialMessage] to have the widget auto-send a first user turn
/// immediately after the greeting arrives — useful for "explain this"
/// flows where the user shouldn't need to type to get reasoning.
class ChatWidget extends StatefulWidget {
  /// Creates a [ChatWidget].
  const ChatWidget({
    super.key,
    required this.backend,
    this.onMutations,
    this.initialMessage,
    this.currentUserId = 'user',
    this.agentUserId = 'agent',
    this.currentUserName = 'You',
    this.agentUserName = 'Assistant',
    this.agentIcon = Icons.smart_toy_outlined,
    this.composerHint = 'Type a message...',
    this.thinkingHint = 'Thinking...',
    this.emptyChatText = 'Send a message to get started',
    this.startErrorText = 'Failed to start chat session',
    this.sendErrorText = 'Failed to send message. Try again.',
    this.timeFormat,
  });

  /// Backend integration providing the greeting and per-turn responses.
  final ChatBackend backend;

  /// Invoked when a turn reports [ChatTurnResult.hadMutations] as `true`.
  ///
  /// Hosts typically use this to refresh data that the agent has
  /// changed (e.g., re-fetching an entity that was edited by a tool call).
  final VoidCallback? onMutations;

  /// Optional first user message sent automatically after the greeting.
  ///
  /// Lets callers pre-seed the conversation topic without requiring the
  /// user to type.
  final String? initialMessage;

  /// Stable identifier used to tag messages authored by the human user.
  final String currentUserId;

  /// Stable identifier used to tag messages authored by the agent.
  final String agentUserId;

  /// Display name shown for the current user.
  final String currentUserName;

  /// Display name shown for the agent.
  final String agentUserName;

  /// Icon rendered in the avatar beside each agent message.
  final IconData agentIcon;

  /// Placeholder text shown in the composer when idle.
  final String composerHint;

  /// Placeholder text shown in the composer while a response is pending.
  final String thinkingHint;

  /// Empty-state message shown before any messages exist.
  final String emptyChatText;

  /// Error banner text shown when [ChatBackend.start] fails.
  final String startErrorText;

  /// Error banner text shown when [ChatBackend.sendMessage] fails.
  final String sendErrorText;

  /// Format used to render message timestamps.
  ///
  /// Defaults to `DateFormat('h:mm a')`.
  final DateFormat? timeFormat;

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final _chatController = _LocalChatController();
  final _scrollController = ScrollController();
  final _crossCache = CrossCache();
  late final DateFormat _timeFormat;

  bool _isStarting = true;
  bool _isSending = false;
  String? _error;
  List<String> _suggestions = const [];
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _timeFormat = widget.timeFormat ?? DateFormat('h:mm a');
    _startSession();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _newId() => 'msg-${_nextId++}';

  Future<void> _startSession() async {
    try {
      final result = await widget.backend.start();
      if (!mounted) return;

      await _chatController.insertMessage(
        TextMessage(
          id: _newId(),
          authorId: widget.agentUserId,
          createdAt: DateTime.now(),
          text: result.greeting,
        ),
      );

      setState(() {
        _suggestions = result.suggestions;
        _isStarting = false;
      });

      if (widget.initialMessage != null) {
        await _sendMessage(widget.initialMessage!);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = widget.startErrorText;
        _isStarting = false;
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    final message = text.trim();
    if (message.isEmpty || _isSending) return;

    await _chatController.insertMessage(
      TextMessage(
        id: _newId(),
        authorId: widget.currentUserId,
        createdAt: DateTime.now(),
        text: message,
      ),
    );

    setState(() {
      _suggestions = const [];
      _isSending = true;
      _error = null;
    });

    try {
      final result = await widget.backend.sendMessage(message);
      if (!mounted) return;

      await _chatController.insertMessage(
        TextMessage(
          id: _newId(),
          authorId: widget.agentUserId,
          createdAt: DateTime.now(),
          text: result.response,
        ),
      );

      setState(() {
        _suggestions = result.suggestions;
        _isSending = false;
      });

      if (result.hadMutations) {
        widget.onMutations?.call();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = widget.sendErrorText;
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: _isStarting
              ? const Center(child: CircularProgressIndicator())
              : Chat(
                  builders: Builders(
                    chatAnimatedListBuilder: (context, itemBuilder) {
                      return ChatAnimatedList(
                        scrollController: _scrollController,
                        itemBuilder: itemBuilder,
                        shouldScrollToEndWhenAtBottom: false,
                      );
                    },
                    textMessageBuilder: _textMessageBuilder,
                    composerBuilder: (_) => _buildComposer(),
                    emptyChatListBuilder: (_) =>
                        EmptyChatList(text: widget.emptyChatText),
                  ),
                  chatController: _chatController,
                  crossCache: _crossCache,
                  currentUserId: widget.currentUserId,
                  onMessageSend: _sendMessage,
                  resolveUser: (id) => Future.value(
                    User(
                      id: id,
                      name: id == widget.currentUserId
                          ? widget.currentUserName
                          : widget.agentUserName,
                    ),
                  ),
                  theme: ChatTheme.fromThemeData(theme),
                  timeFormat: _timeFormat,
                ),
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.errorContainer,
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        if (_suggestions.isNotEmpty) ...[
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ActionChip(
                  label: Text(suggestion),
                  onPressed: _isSending ? null : () => _sendMessage(suggestion),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _textMessageBuilder(
    BuildContext context,
    TextMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final theme = Theme.of(context);
    final isAgent = message.authorId == widget.agentUserId;

    final textWidget = FlyerChatTextMessage(
      message: message,
      index: index,
      showTime: false,
      showStatus: false,
      sentBackgroundColor: theme.colorScheme.primaryContainer,
      receivedBackgroundColor: isAgent
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.surfaceContainerHigh,
      sentTextStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onPrimaryContainer,
      ),
      receivedTextStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      borderRadius: BorderRadius.circular(12),
    );

    if (isSentByMe) return textWidget;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Icon(
              widget.agentIcon,
              size: 16,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        Flexible(child: textWidget),
      ],
    );
  }

  Widget _buildComposer() {
    return Composer(
      sendButtonDisabled: _isSending,
      hintText: _isSending ? widget.thinkingHint : widget.composerHint,
    );
  }
}

/// A [ChatController] that manages messages entirely in local memory.
///
/// The widget owns the controller lifecycle; we don't persist messages
/// here because the backing [ChatBackend] is the source of truth for
/// conversation history.
class _LocalChatController
    with UploadProgressMixin, ScrollToMessageMixin
    implements ChatController {
  List<Message> _messages = [];
  final _operationsController = StreamController<ChatOperation>.broadcast();

  @override
  Future<void> insertMessage(
    Message message, {
    int? index,
    bool animated = true,
  }) async {
    if (index == null) {
      _messages.add(message);
      _operationsController.add(
        ChatOperation.insert(message, _messages.length - 1, animated: animated),
      );
    } else {
      _messages.insert(index, message);
      _operationsController.add(
        ChatOperation.insert(message, index, animated: animated),
      );
    }
  }

  @override
  Future<void> insertAllMessages(
    List<Message> messages, {
    int? index,
    bool animated = true,
  }) async {
    if (messages.isEmpty) return;

    if (index == null) {
      final start = _messages.length;
      _messages.addAll(messages);
      _operationsController.add(
        ChatOperation.insertAll(messages, start, animated: animated),
      );
    } else {
      _messages.insertAll(index, messages);
      _operationsController.add(
        ChatOperation.insertAll(messages, index, animated: animated),
      );
    }
  }

  @override
  Future<void> removeMessage(Message message, {bool animated = true}) async {
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      final removed = _messages.removeAt(index);
      _operationsController.add(
        ChatOperation.remove(removed, index, animated: animated),
      );
    }
  }

  @override
  Future<void> updateMessage(Message oldMessage, Message newMessage) async {
    final index = _messages.indexWhere((m) => m.id == oldMessage.id);
    if (index != -1) {
      _messages[index] = newMessage;
      _operationsController.add(
        ChatOperation.update(oldMessage, newMessage, index),
      );
    }
  }

  @override
  Future<void> setMessages(
    List<Message> messages, {
    bool animated = true,
  }) async {
    _messages = List.from(messages);
    _operationsController.add(ChatOperation.set(_messages, animated: animated));
  }

  @override
  List<Message> get messages => _messages;

  @override
  Stream<ChatOperation> get operationsStream => _operationsController.stream;

  @override
  void dispose() {
    _operationsController.close();
    disposeUploadProgress();
    disposeScrollMethods();
  }
}
