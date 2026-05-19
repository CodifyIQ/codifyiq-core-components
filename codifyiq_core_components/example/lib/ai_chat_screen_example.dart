import 'package:codifyiq_core_components/codifyiq_core_components.dart';
import 'package:flutter/material.dart';

/// Demo for [AiChatScreen] paired with [ChatHistorySidebar].
///
/// The sidebar lists ten mock conversations. Selecting one switches the active
/// [AiChatController]; each controller owns its own independent message
/// history. Type "pdf", "image", or "fail" in any chat to exercise those
/// response paths.
class AiChatScreenExample extends StatefulWidget {
  /// Creates an [AiChatScreenExample].
  const AiChatScreenExample({super.key});

  @override
  State<AiChatScreenExample> createState() => _AiChatScreenExampleState();
}

class _AiChatScreenExampleState extends State<AiChatScreenExample> {
  static final _seed = DateTime.now();

  // A reliable public PDF used for demo file messages.
  static final Uri _samplePdfUri = Uri.parse(
    'https://raw.githubusercontent.com/mozilla/pdf.js/master/test/pdfs/tracemonkey.pdf',
  );

  static List<ChatHistoryItem> _buildMockChats() => [
    ChatHistoryItem(
      id: '1',
      title: 'Explain quantum computing in simple terms',
      updatedAt: _seed.subtract(const Duration(minutes: 2)),
    ),
    ChatHistoryItem(
      id: '2',
      title: 'Write a Flutter widget for image picking',
      updatedAt: _seed.subtract(const Duration(hours: 1)),
    ),
    ChatHistoryItem(
      id: '3',
      title: 'Review my pull request — auth middleware refactor',
      updatedAt: _seed.subtract(const Duration(hours: 3)),
    ),
    ChatHistoryItem(
      id: '4',
      title: 'Debug async stream backpressure in Dart',
      updatedAt: _seed.subtract(const Duration(days: 1)),
    ),
    ChatHistoryItem(
      id: '5',
      title: 'Translate contract to French',
      updatedAt: _seed.subtract(const Duration(days: 2)),
    ),
    ChatHistoryItem(
      id: '6',
      title: 'REST vs GraphQL — when to use which?',
      updatedAt: _seed.subtract(const Duration(days: 3)),
    ),
    ChatHistoryItem(
      id: '7',
      title: 'Generate a SQL schema for a multi-tenant SaaS',
      updatedAt: _seed.subtract(const Duration(days: 5)),
    ),
    ChatHistoryItem(
      id: '8',
      title: 'Fix the memory leak in my iOS background worker',
      updatedAt: _seed.subtract(const Duration(days: 7)),
    ),
    ChatHistoryItem(
      id: '9',
      title: 'Summarize this research paper on diffusion models',
      updatedAt: _seed.subtract(const Duration(days: 14)),
    ),
    ChatHistoryItem(
      id: '10',
      title: 'Create a go-to-market plan for my dev tools startup',
      updatedAt: _seed.subtract(const Duration(days: 21)),
    ),
  ];

  late final List<ChatHistoryItem> _initialChats = _buildMockChats();
  late List<ChatHistoryItem> _chats = List.of(_initialChats);
  late String _activeChatId = _chats.first.id;
  bool _isCollapsed = true;
  int _newChatCounter = 0;

  late final Map<String, AiChatController> _controllers = {
    for (final chat in _initialChats) chat.id: _makeController(chat.title),
  };

  AiChatController _makeController(String title) => AiChatController(
    responder: _demoResponder,
    initialMessages: [
      CodifyChatMessage.ai(
        text:
            'Hi! You opened **"$title"**.\n\n'
            'Send a message — or include the words **"pdf"**, **"image"**, '
            'or **"fail"** to try those response types.',
      ),
    ],
  );

  Future<CodifyChatMessage> _demoResponder(String prompt) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final lower = prompt.toLowerCase();
    if (lower.contains('fail')) throw Exception('Simulated backend failure');
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
          'You said: **"$prompt"**\n\n'
          'This is a simulated reply rendered as **Markdown**. A real app '
          'would wire `AiChatController` to its backend via the responder '
          'callback.',
    );
  }

  void _addNewChat() {
    _newChatCounter++;
    final id = 'new-$_newChatCounter';
    final chat = ChatHistoryItem(
      id: id,
      title: 'New conversation $_newChatCounter',
      updatedAt: DateTime.now(),
    );
    _controllers[id] = _makeController(chat.title);
    setState(() {
      _chats = [chat, ..._chats];
      _activeChatId = id;
    });
  }

  AiChatController get _activeController {
    assert(
      _controllers.containsKey(_activeChatId),
      'No AiChatController found for active chat id "$_activeChatId". '
      'Ensure _controllers is populated before _activeChatId is set.',
    );
    return _controllers[_activeChatId]!;
  }

  void _handleAttachImage() {
    _activeController.addMessage(
      CodifyChatMessage.image(
        text: 'photo.png',
        sender: CodifyChatSender.user,
        sourceUri: Uri.parse(
          'https://picsum.photos/seed/codifyiq-photo/600/400',
        ),
      ),
    );
  }

  void _handleAttachPdf() {
    _activeController.addMessage(
      CodifyChatMessage.pdf(
        text: 'contract.pdf',
        sender: CodifyChatSender.user,
        sourceUri: _samplePdfUri,
        fileSizeBytes: 1055688,
      ),
    );
  }

  void _handleMessageTap(CodifyChatMessage message) {
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
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Chat Example')),
      body: Stack(
        children: [
          // Full-width chat — never affected by the sidebar.
          Positioned.fill(
            child: AiChatScreen(
              key: ValueKey(_activeChatId),
              controller: _activeController,
              inputHint: 'Ask anything…',
              onMessageTap: _handleMessageTap,
              onAttachImage: _handleAttachImage,
              onAttachPdf: _handleAttachPdf,
            ),
          ),

          if (_isCollapsed)
            // Collapsed: small floating pill at the top-left corner.
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                elevation: 2,
                shadowColor: Colors.black,
                child: IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Open conversations',
                  onPressed: () => setState(() => _isCollapsed = false),
                ),
              ),
            )
          else
            // Expanded: full-height sidebar with a drop shadow.
            Positioned(
              top: 0,
              left: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: ChatHistorySidebar(
                  chats: _chats,
                  activeChatId: _activeChatId,
                  onChatSelected: (chat) =>
                      setState(() => _activeChatId = chat.id),
                  onToggleCollapse: () =>
                      setState(() => _isCollapsed = true),
                  onNewChat: _addNewChat,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
