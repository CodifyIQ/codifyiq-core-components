import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../ai_progress_indicator.dart';
import 'ai_chat_controller.dart';
import 'codify_chat_message.dart';
import 'flyer_chat_mapper.dart';

/// An embeddable AI chat experience for the CodifyIQ design system.
///
/// [AiChatScreen] wraps the Flyer Chat (`flutter_chat_ui`) `Chat` widget — it
/// does not reimplement the scrollable timeline, message bubbles, auto-scroll,
/// or input bar — and re-skins it with Material 3 colors from the ambient
/// [Theme]. It renders only the chat area, with no [Scaffold] or [AppBar], so
/// it can be embedded anywhere.
///
/// Drive it with an [AiChatController]: the controller owns the timeline and
/// the backend round-trip, and this widget rebuilds when it changes.
///
/// ## MVP behavior
///
/// - Text messaging with a multiline input and a send button (Flyer-provided)
///   that stays visible, grayed out while the field is empty or a reply is in
///   flight. Sending is blocked while a reply is in flight, and the draft text
///   is preserved rather than cleared.
/// - AI replies render as Markdown (headings, bold, lists, code, links); user
///   messages render as plain text.
/// - On wide (desktop) viewports the conversation is centered in a column
///   capped at [maxContentWidth].
/// - Image messages render inline via Flyer Chat. Tapping one opens the
///   built-in zoom gallery by default, or — with [enableImageGallery] set to
///   `false` — is forwarded to [onMessageTap] for a custom viewer, exactly
///   like PDF.
/// - PDF messages render as tappable file rows; the tap is forwarded to
///   [onMessageTap] so the host can open its own PDF viewer.
/// - A `+` attachment button opens an "Add image / Add PDF" menu whenever
///   [onAttachImage] and/or [onAttachPdf] are provided; it is hidden when both
///   are null. The host app performs the actual file picking.
/// - While a reply is awaited, an [AiProgressIndicator] is shown in Flyer's
///   typing-indicator slot.
/// - A message's `seenAt` is stamped automatically the first time it scrolls
///   into view.
class AiChatScreen extends StatefulWidget {
  /// Creates an [AiChatScreen].
  const AiChatScreen({
    super.key,
    required this.controller,
    this.onSendMessage,
    this.onMessageTap,
    this.enableImageGallery = true,
    this.onAttachImage,
    this.onAttachPdf,
    this.inputHint,
    this.emptyState,
    this.maxContentWidth = 760,
  });

  /// Owns the message timeline, send lifecycle, and `seenAt` updates.
  final AiChatController controller;

  /// Called with the raw text the moment the user taps send, just before the
  /// controller dispatches it. Purely observational — the controller still
  /// performs the send.
  final void Function(String text)? onSendMessage;

  /// Called when the user taps a message bubble.
  ///
  /// The PDF/image viewer integration hooks in here: inspect
  /// [CodifyChatMessage.kind] and [CodifyChatMessage.sourceUri] to open the
  /// appropriate viewer. Always fires for PDF taps, and for image taps too —
  /// see [enableImageGallery].
  final void Function(CodifyChatMessage message)? onMessageTap;

  /// Whether tapping an image opens Flyer Chat's built-in full-screen,
  /// pinch-to-zoom gallery.
  ///
  /// Defaults to `true`. Set to `false` to suppress the built-in gallery so
  /// an image tap is delivered *only* through [onMessageTap] — wire that to
  /// your own image viewer, the same way PDF taps are handled. [onMessageTap]
  /// fires regardless of this flag.
  final bool enableImageGallery;

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

  /// Optional placeholder text for the input field.
  final String? inputHint;

  /// Optional widget shown when the timeline is empty.
  final Widget? emptyState;

  /// Maximum width of the chat column.
  ///
  /// On wide (desktop) viewports the timeline and input bar are centered and
  /// capped at this width so the conversation does not sprawl across the
  /// screen; the side gutters are painted in a dimmed surface tone so the
  /// column reads as a contained area. Defaults to `760`. Pass `null` to let
  /// the chat fill all available width (no gutters).
  final double? maxContentWidth;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  // Held so the send button can react to the input's contents. Flyer's Input
  // widget exposes no send-button builder, but it does accept an external text
  // controller and a themed send icon — together those let the icon gray
  // itself out while the field is empty.
  //
  // Deliberately NOT disposed here: flutter_chat_ui's Input takes ownership of
  // the controller passed via InputOptions.textEditingController and disposes
  // it itself. Disposing it again would double-dispose and crash.
  final InputTextFieldController _inputController = InputTextFieldController();

  // Anchors the attachment menu to the `+` button. The key rides on the
  // themed attachment icon, which Flyer renders inside the button.
  final GlobalKey _attachButtonKey = GlobalKey();

  /// Whether at least one attachment callback is wired — drives whether the
  /// `+` button is shown at all.
  bool get _attachEnabled =>
      widget.onAttachImage != null || widget.onAttachPdf != null;

  /// Opens the "Add image / Add PDF" menu anchored to the `+` button, then
  /// dispatches the host callback for the chosen option.
  Future<void> _showAttachMenu() async {
    // With only one attachment type wired, skip the menu and open that picker
    // directly. (_showAttachMenu is only reachable when at least one callback
    // is set, so the other is guaranteed non-null past these guards.)
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
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final Widget chat = Chat(
          messages: toFlyerMessages(widget.controller.messages),
          user: userAuthor,
          theme: _buildChatTheme(theme),
          l10n: ChatL10nEn(
            inputPlaceholder: widget.inputHint ?? 'Message',
            attachmentButtonAccessibilityLabel: 'Attach',
          ),
          emptyState: widget.emptyState,
          // When the host opts out, an image tap skips Flyer's gallery and is
          // delivered through onMessageTap only — symmetric with PDF.
          disableImageGallery: !widget.enableImageGallery,
          // A null onAttachmentPressed makes Flyer hide the `+` button, so it
          // only appears when the host wired up at least one attach callback.
          onAttachmentPressed: _attachEnabled ? _showAttachMenu : null,
          inputOptions: InputOptions(
            textEditingController: _inputController,
            // Keep the send button on screen at all times; _buildChatTheme
            // grays its icon out while the field is empty or a reply is in
            // flight.
            sendButtonVisibilityMode: SendButtonVisibilityMode.always,
            // Clear the field ourselves (in onSendPressed) only on an accepted
            // send — so a send attempted while responding keeps the draft.
            inputClearMode: InputClearMode.never,
          ),
          onSendPressed: (partialText) {
            // Block sends while a reply is in flight. Returning early here
            // also skips the clear below, so the user's draft is preserved.
            if (widget.controller.isResponding) return;
            widget.onSendMessage?.call(partialText.text);
            widget.controller.sendText(partialText.text);
            _inputController.clear();
          },
          onMessageTap: (_, message) {
            final tapped = widget.controller.messageById(message.id);
            if (tapped != null) widget.onMessageTap?.call(tapped);
          },
          onMessageVisibilityChanged: (message, visible) {
            if (visible) widget.controller.markSeen(message.id);
          },
          textMessageBuilder:
              (message, {required messageWidth, required showName}) {
                return _TextMessageContent(
                  message: message,
                  maxWidth: messageWidth.toDouble(),
                );
              },
          customMessageBuilder: (message, {required int messageWidth}) {
            return _CustomMessageBubble(
              message: widget.controller.messageById(message.id),
              maxWidth: messageWidth.toDouble(),
            );
          },
          typingIndicatorOptions: TypingIndicatorOptions(
            typingUsers: widget.controller.isResponding
                ? const <types.User>[aiAuthor]
                : const <types.User>[],
            customTypingIndicatorBuilder:
                ({
                  required context,
                  required bubbleAlignment,
                  required options,
                  required indicatorOnScrollStatus,
                }) => const _ThinkingIndicator(),
          ),
        );

        final maxWidth = widget.maxContentWidth;
        if (maxWidth == null) return chat;
        // Center the conversation in a capped column on wide (desktop)
        // viewports. The gutters take a dimmed surface tone so the column
        // reads as an intentional, contained area rather than content
        // floating in empty space. On narrow screens the column fills the
        // width and the gutters are not visible.
        return ColoredBox(
          color: theme.colorScheme.surfaceContainer,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: chat,
            ),
          ),
        );
      },
    );
  }

  /// Derives a Flyer [ChatTheme] from the ambient Material 3 [ThemeData] so
  /// the chat matches the surrounding CodifyIQ app.
  ChatTheme _buildChatTheme(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final bodyStyle = theme.textTheme.bodyLarge ?? const TextStyle();
    return DefaultChatTheme(
      backgroundColor: colorScheme.surface,
      primaryColor: colorScheme.primary,
      secondaryColor: colorScheme.surfaceContainerHighest,
      sentMessageBodyTextStyle: bodyStyle.copyWith(
        color: colorScheme.onPrimary,
      ),
      receivedMessageBodyTextStyle: bodyStyle.copyWith(
        color: colorScheme.onSurface,
      ),
      emptyChatPlaceholderTextStyle: bodyStyle.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      dateDividerTextStyle: (theme.textTheme.labelSmall ?? const TextStyle())
          .copyWith(color: colorScheme.onSurfaceVariant),
      inputBackgroundColor: colorScheme.surfaceContainerHighest,
      inputSurfaceTintColor: colorScheme.surfaceTint,
      inputTextColor: colorScheme.onSurface,
      inputTextCursorColor: colorScheme.primary,
      inputContainerDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
      ),
      receivedMessageDocumentIconColor: colorScheme.primary,
      sentMessageDocumentIconColor: colorScheme.onPrimary,
      sendButtonIcon: _SendButtonIcon(
        controller: _inputController,
        isResponding: widget.controller.isResponding,
      ),
      // The key rides on the icon so _showAttachMenu can anchor the menu to
      // the `+` button's on-screen position.
      attachmentButtonIcon: KeyedSubtree(
        key: _attachButtonKey,
        child: Icon(Icons.add, color: colorScheme.onSurfaceVariant),
      ),
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

/// Renders a text message inside Flyer's bubble.
///
/// AI replies are rendered as Markdown — AI backends typically return Markdown
/// — while user messages stay plain text.
class _TextMessageContent extends StatelessWidget {
  const _TextMessageContent({required this.message, required this.maxWidth});

  final types.TextMessage message;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFromAi = message.author.id == aiAuthor.id;
    final bodyStyle = (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
      color: isFromAi
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onPrimary,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: isFromAi
            ? GptMarkdown(message.text, style: bodyStyle)
            : Text(message.text, style: bodyStyle),
      ),
    );
  }
}

/// Renders the placeholder / error bubbles for non-text messages.
///
/// The content sits inside Flyer's received-message bubble (painted with
/// [ChatTheme.secondaryColor]); the error variant paints its own background
/// to override that color.
class _CustomMessageBubble extends StatelessWidget {
  const _CustomMessageBubble({required this.message, required this.maxWidth});

  final CodifyChatMessage? message;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    if (message == null) return const SizedBox.shrink();

    switch (message.kind) {
      case CodifyChatMessageKind.pdf:
        return _PlaceholderBubble(
          maxWidth: maxWidth,
          text: '📄 PDF message (no file attached).',
        );
      case CodifyChatMessageKind.image:
        return _PlaceholderBubble(
          maxWidth: maxWidth,
          text: '🖼️ Image message (no file attached).',
        );
      case CodifyChatMessageKind.error:
        return _ErrorBubble(maxWidth: maxWidth, text: message.text);
      case CodifyChatMessageKind.text:
        // Text messages never reach the custom builder.
        return const SizedBox.shrink();
    }
  }
}

/// A neutral bubble used for not-yet-supported PDF/image responses.
class _PlaceholderBubble extends StatelessWidget {
  const _PlaceholderBubble({required this.text, required this.maxWidth});

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A bubble that surfaces a failed chat turn in the theme's error colors.
class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.text, required this.maxWidth});

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        color: theme.colorScheme.errorContainer,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              size: 20,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The loading indicator shown in Flyer's typing-indicator slot while the
/// backend request is in flight. Reuses the package's [AiProgressIndicator].
class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: AiProgressIndicator(
          text: 'Thinking…',
          textStyle: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

/// The send-button icon, tinted to reflect whether a send is currently
/// possible.
///
/// Flyer's `Input` always renders the send button (see
/// [SendButtonVisibilityMode.always]); this widget listens to the input's
/// [TextEditingController] and grays the icon out while the field is empty or
/// a reply is in flight ([isResponding]), restoring the primary color only
/// when the user has typed something and no request is pending.
class _SendButtonIcon extends StatelessWidget {
  const _SendButtonIcon({required this.controller, required this.isResponding});

  final TextEditingController controller;
  final bool isResponding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final canSend = !isResponding && controller.text.trim().isNotEmpty;
        return Icon(
          Icons.send_rounded,
          color: canSend
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.38),
        );
      },
    );
  }
}
