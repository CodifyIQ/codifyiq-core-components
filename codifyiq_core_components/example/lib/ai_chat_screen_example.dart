import 'package:codifyiq_core_components/codifyiq_core_components.dart';
import 'package:flutter/material.dart';

/// Demo for [AiChatScreen] and [AiChatController].
///
/// A simulated backend echoes text replies after a short delay. Type a prompt
/// containing certain keywords to exercise the other code paths:
///
/// - `pdf`   → a placeholder PDF response bubble
/// - `image` → a placeholder image response bubble
/// - `fail`  → a thrown error, surfaced as an error bubble
class AiChatScreenExample extends StatefulWidget {
  /// Creates an [AiChatScreenExample].
  const AiChatScreenExample({super.key});

  @override
  State<AiChatScreenExample> createState() => _AiChatScreenExampleState();
}

class _AiChatScreenExampleState extends State<AiChatScreenExample> {
  late final AiChatController _controller = AiChatController(
    responder: _demoResponder,
    initialMessages: [
      CodifyChatMessage.ai(
        text:
            "Hi! I'm a demo assistant. Send me a message — or include the "
            "words \"pdf\", \"image\", or \"fail\" to try those response "
            "types.",
      ),
    ],
  );

  /// Stands in for a real backend call.
  // A reliable public PDF used to demonstrate file messages end to end.
  static final Uri _samplePdfUri = Uri.parse(
    'https://raw.githubusercontent.com/mozilla/pdf.js/master/test/pdfs/tracemonkey.pdf',
  );

  Future<CodifyChatMessage> _demoResponder(String prompt) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final lower = prompt.toLowerCase();

    if (lower.contains('fail')) {
      throw Exception('Simulated backend failure');
    }
    if (lower.contains('pdf')) {
      return CodifyChatMessage.pdf(
        text: 'quarterly-report.pdf',
        sourceUri: _samplePdfUri,
        fileSizeBytes: 1055688,
      );
    }
    if (lower.contains('image')) {
      return CodifyChatMessage.image(
        text: 'architecture-diagram.png',
        sourceUri: Uri.parse('https://picsum.photos/seed/codifyiq-ai/600/400'),
      );
    }
    return CodifyChatMessage.ai(
      text:
          'You said: **"$prompt"**.\n\n'
          'This is a simulated reply, rendered as **Markdown**. A real app '
          'would wire `AiChatController` to its backend via the responder '
          'callback. Markdown supports:\n\n'
          '- **bold** and *italic* text\n'
          '- inline `code` and code blocks\n'
          '- lists, headings, and links\n',
    );
  }

  // A real app would open an image picker here; this demo simulates a picked
  // file by appending a message that points at a sample network image.
  void _handleAttachImage() {
    _controller.addMessage(
      CodifyChatMessage.image(
        text: 'photo.png',
        sender: CodifyChatSender.user,
        sourceUri: Uri.parse(
          'https://picsum.photos/seed/codifyiq-photo/600/400',
        ),
      ),
    );
  }

  // Likewise for PDFs — the host app owns the document picker.
  void _handleAttachPdf() {
    _controller.addMessage(
      CodifyChatMessage.pdf(
        text: 'contract.pdf',
        sender: CodifyChatSender.user,
        sourceUri: _samplePdfUri,
        fileSizeBytes: 1055688,
      ),
    );
  }

  void _handleMessageTap(CodifyChatMessage message) {
    // Only PDF taps have a host action here: the chat widget never imports a
    // PDF renderer, so the host wires onMessageTap to its own viewer — the
    // package's PdfViewerWidget. Image taps are handled by Flyer's built-in
    // gallery, and text/error taps have no natural action, so they are
    // intentionally ignored.
    if (message.kind == CodifyChatMessageKind.pdf &&
        message.sourceUri != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: Text(message.text.isEmpty ? 'PDF' : message.text),
            ),
            body: PdfViewerWidget(source: PdfSource.uri(message.sourceUri!)),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Chat Example')),
      body: AiChatScreen(
        controller: _controller,
        inputHint: 'Ask the assistant…',
        onSendMessage: (text) => debugPrint('Sending: $text'),
        onMessageTap: _handleMessageTap,
        onAttachImage: _handleAttachImage,
        onAttachPdf: _handleAttachPdf,
      ),
    );
  }
}
