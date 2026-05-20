import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flyer_chat_file_message/flyer_chat_file_message.dart';
import 'package:flyer_chat_image_message/flyer_chat_image_message.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../ai_progress_indicator.dart';
import 'ai_chat_controller.dart';
import 'codify_chat_message.dart';
import 'flyer_chat_mapper.dart';

/// An embeddable AI chat experience for the CodifyIQ design system.
///
/// [AiChatScreen] wraps the Flyer Chat (`flutter_chat_ui` v2) `Chat` widget,
/// re-skinned from the ambient Material 3 [Theme]. It renders only the chat
/// area — no [Scaffold] or [AppBar] — so it can be embedded anywhere.
///
/// Drive it with an [AiChatController]: the controller owns the timeline, the
/// backend round-trip, and the Flyer `ChatController` this widget renders.
///
/// ## Behaviour
///
/// - Text messaging with a multiline composer. Messages render as Markdown;
///   the send button is grayed out while the field is empty or a reply is in
///   flight, and sending is blocked (the draft is preserved) during a reply.
/// - Image messages render inline; PDF messages render as tappable file rows.
///   Taps are forwarded to [onMessageTap] so the host can open its own viewer.
/// - A `+` attachment button opens an "Add image / Add PDF" menu whenever
///   [onAttachImage] and/or [onAttachPdf] are provided; it is hidden when both
///   are null. The host app performs the actual file picking.
/// - While a reply is awaited, an [AiProgressIndicator] is shown above the
///   composer.
/// - An AI message's `seenAt` is stamped automatically the first time it
///   scrolls into view.
/// - On wide (desktop) viewports the conversation is centered in a column
///   capped at [maxContentWidth].
class AiChatScreen extends StatefulWidget {
  /// Creates an [AiChatScreen].
  const AiChatScreen({
    super.key,
    required this.controller,
    this.onSendMessage,
    this.onMessageTap,
    this.onAttachImage,
    this.onAttachPdf,
    this.inputHint,
    this.emptyState,
    this.maxContentWidth = 760,
  });

  /// Owns the message timeline, send lifecycle, and `seenAt` updates.
  final AiChatController controller;

  /// Called with the raw text the moment the user taps send, just before the
  /// controller dispatches it. Purely observational.
  final void Function(String text)? onSendMessage;

  /// Called when the user taps a message bubble.
  ///
  /// The PDF/image viewer integration hooks in here: inspect
  /// [CodifyChatMessage.kind] and [CodifyChatMessage.sourceUri] to open the
  /// appropriate viewer.
  final void Function(CodifyChatMessage message)? onMessageTap;

  /// Called when the user picks "Add image" from the `+` attachment menu.
  ///
  /// The package ships no file picker: the host app opens an image picker and
  /// adds the resulting message itself (e.g. via [AiChatController.addMessage]
  /// with [CodifyChatMessage.image]). When both this and [onAttachPdf] are
  /// null, the attachment button is hidden.
  final VoidCallback? onAttachImage;

  /// Called when the user picks "Add PDF" from the `+` attachment menu.
  ///
  /// The host app opens the document picker and adds the resulting message
  /// itself. When both this and [onAttachImage] are null, the attachment
  /// button is hidden.
  final VoidCallback? onAttachPdf;

  /// Optional placeholder text for the composer input field.
  final String? inputHint;

  /// Optional widget shown when the timeline is empty.
  final Widget? emptyState;

  /// Maximum width of the chat column.
  ///
  /// On wide (desktop) viewports the timeline and composer are centered and
  /// capped at this width so the conversation does not sprawl across the
  /// screen; the side gutters are painted in a dimmed surface tone so the
  /// column reads as a contained area. Defaults to `760`. Pass `null` to let
  /// the chat fill all available width (no gutters).
  final double? maxContentWidth;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  // Owned here and disposed in dispose(): Flyer's v2 Composer does NOT dispose
  // a controller passed in via `textEditingController`.
  final TextEditingController _composerController = TextEditingController();

  // Anchors the attachment menu to the `+` button. The key rides on the
  // composer's attachment icon.
  final GlobalKey _attachButtonKey = GlobalKey();

  /// Whether at least one attachment callback is wired — drives whether the
  /// `+` button is shown at all.
  bool get _attachEnabled =>
      widget.onAttachImage != null || widget.onAttachPdf != null;

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  void _handleSend(String text) {
    // Block sends while a reply is in flight; returning early also skips the
    // clear below (inputClearMode is `never`), so the draft is preserved.
    if (widget.controller.isResponding) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    widget.onSendMessage?.call(trimmed);
    widget.controller.sendText(trimmed);
    _composerController.clear();
  }

  void _handleMessageTap(
    BuildContext context,
    Message message, {
    required int index,
    required TapUpDetails details,
  }) {
    final tapped = widget.controller.messageById(message.id);
    if (tapped != null) widget.onMessageTap?.call(tapped);
  }

  /// Wraps a message widget so an AI message's `seenAt` is stamped the first
  /// time it scrolls into view (v2 has no built-in visibility callback).
  ///
  /// The user's own messages are not tracked — marking them "seen" is
  /// meaningless and would surface a misleading status indicator.
  Widget _messageItem(String id, bool isSentByMe, Widget child) {
    if (isSentByMe) return child;
    return VisibilityDetector(
      key: ValueKey('codify-chat-seen-$id'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0) widget.controller.markSeen(id);
      },
      child: child,
    );
  }

  Widget _buildTextMessage(
    BuildContext context,
    TextMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) => _messageItem(
    message.id,
    isSentByMe,
    FlyerChatTextMessage(message: message, index: index),
  );

  Widget _buildImageMessage(
    BuildContext context,
    ImageMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) => _messageItem(
    message.id,
    isSentByMe,
    FlyerChatImageMessage(message: message, index: index),
  );

  Widget _buildFileMessage(
    BuildContext context,
    FileMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) => _messageItem(
    message.id,
    isSentByMe,
    FlyerChatFileMessage(message: message, index: index),
  );

  Widget _buildCustomMessage(
    BuildContext context,
    CustomMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) => _messageItem(
    message.id,
    isSentByMe,
    _CustomMessageBubble(message: widget.controller.messageById(message.id)),
  );

  Widget _buildEmptyState(BuildContext context) => widget.emptyState!;

  Widget _buildComposer(BuildContext context) => _ChatComposer(
    controller: widget.controller,
    textController: _composerController,
    attachButtonKey: _attachButtonKey,
    hintText: widget.inputHint ?? 'Message',
  );

  /// Opens the "Add image / Add PDF" menu anchored to the `+` button, then
  /// dispatches the host callback for the chosen option.
  Future<void> _showAttachMenu() async {
    // With only one attachment type wired, skip the menu and open that picker
    // directly. (This is only reachable when at least one callback is set, so
    // the other is guaranteed non-null past these guards.)
    if (widget.onAttachPdf == null) {
      widget.onAttachImage?.call();
      return;
    }
    if (widget.onAttachImage == null) {
      widget.onAttachPdf?.call();
      return;
    }

    final buttonContext = _attachButtonKey.currentContext;
    if (buttonContext == null) return;
    final button = buttonContext.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<CodifyChatMessageKind>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem<CodifyChatMessageKind>(
          value: CodifyChatMessageKind.image,
          child: _AttachMenuItem(
            icon: Icons.image_outlined,
            label: 'Add image',
          ),
        ),
        PopupMenuItem<CodifyChatMessageKind>(
          value: CodifyChatMessageKind.pdf,
          child: _AttachMenuItem(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Add PDF',
          ),
        ),
      ],
    );

    switch (selected) {
      case CodifyChatMessageKind.image:
        widget.onAttachImage?.call();
      case CodifyChatMessageKind.pdf:
        widget.onAttachPdf?.call();
      case CodifyChatMessageKind.text:
      case CodifyChatMessageKind.error:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Built outside any ListenableBuilder: the message list reacts to the
    // controller through `chatController`'s own stream, and only the composer
    // depends on `isResponding` (it listens for itself). Keeping the builders
    // stable here avoids rebuilding every visible message on each controller
    // notification (e.g. a scroll-driven `markSeen`).
    final Widget chat = Chat(
      currentUserId: userAuthorId,
      resolveUser: resolveCodifyChatUser,
      chatController: widget.controller.chatController,
      theme: ChatTheme.fromThemeData(theme),
      onMessageSend: _handleSend,
      onMessageTap: _handleMessageTap,
      onAttachmentTap: _attachEnabled ? _showAttachMenu : null,
      builders: Builders(
        textMessageBuilder: _buildTextMessage,
        imageMessageBuilder: _buildImageMessage,
        fileMessageBuilder: _buildFileMessage,
        customMessageBuilder: _buildCustomMessage,
        emptyChatListBuilder: widget.emptyState == null
            ? null
            : _buildEmptyState,
        composerBuilder: _buildComposer,
      ),
    );

    final maxWidth = widget.maxContentWidth;
    if (maxWidth == null) return chat;
    // Center the conversation in a capped column on wide (desktop) viewports,
    // with dimmed gutters so the column reads as a contained area. On narrow
    // screens the column fills the width.
    return ColoredBox(
      color: theme.colorScheme.surfaceContainer,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: chat,
        ),
      ),
    );
  }
}

/// The chat composer, isolated so it can rebuild on `isResponding` changes
/// without rebuilding the message list.
class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.textController,
    required this.attachButtonKey,
    required this.hintText,
  });

  final AiChatController controller;
  final TextEditingController textController;
  final Key attachButtonKey;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isResponding = controller.isResponding;
        return Composer(
          textEditingController: textController,
          hintText: hintText,
          attachmentIcon: KeyedSubtree(
            key: attachButtonKey,
            child: const Icon(Icons.add),
          ),
          attachmentIconColor: colorScheme.onSurfaceVariant,
          sendIcon: const Icon(Icons.send_rounded),
          sendIconColor: colorScheme.primary,
          emptyFieldSendIconColor: colorScheme.onSurface.withValues(
            alpha: 0.38,
          ),
          // Grayed + non-tappable while the field is empty (native) or a
          // reply is in flight.
          sendButtonVisibilityMode: SendButtonVisibilityMode.disabled,
          sendButtonDisabled: isResponding,
          // The field is cleared by AiChatScreen only on an accepted send, so
          // a send attempted while responding keeps the draft.
          inputClearMode: InputClearMode.never,
          keyboardType: TextInputType.multiline,
          sendOnEnter: true,
          topWidget: isResponding ? const _ThinkingIndicator() : null,
        );
      },
    );
  }
}

/// A single row in the attachment menu — a leading icon and a label.
class _AttachMenuItem extends StatelessWidget {
  const _AttachMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurface),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}

/// Renders the placeholder / error bubbles for the [CustomMessage]s produced
/// by source-less image/pdf messages and error messages.
class _CustomMessageBubble extends StatelessWidget {
  const _CustomMessageBubble({required this.message});

  final CodifyChatMessage? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    if (message == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final isError = message.kind == CodifyChatMessageKind.error;

    final String text;
    switch (message.kind) {
      case CodifyChatMessageKind.pdf:
        text = '📄 PDF message (no file attached).';
      case CodifyChatMessageKind.image:
        text = '🖼️ Image message (no file attached).';
      case CodifyChatMessageKind.error:
        text = message.text;
      case CodifyChatMessageKind.text:
        // Text messages never reach the custom builder.
        return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isError
              ? colorScheme.errorContainer
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isError) ...[
              Icon(
                Icons.error_outline,
                size: 20,
                color: colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isError
                      ? colorScheme.onErrorContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The loading indicator shown above the composer while a backend request is
/// in flight. Reuses the package's [AiProgressIndicator].
class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AiProgressIndicator(text: 'Thinking…'),
      ),
    );
  }
}
