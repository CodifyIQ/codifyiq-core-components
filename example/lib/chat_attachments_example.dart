import 'dart:async';

import 'package:codifyiq_brightness_button/codifyiq_brightness_button.dart';
import 'package:codifyiq_chat_attachments/codifyiq_chat_attachments.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'caption_sheet.dart';

/// Example page showing [ChatAttachments] inside a Flyer Chat [Chat].
///
/// A static conversation mixes text with images, a PDF, another file, a
/// video and a voice note. Tapping an attachment opens the matching viewer, and Share,
/// Download and opening other files surface feedback through a [SnackBar].
///
/// Images carry a small thumbnail in their metadata, so the chat loads only
/// thumbnails and the full photo downloads when it is opened. The composer's
/// attachment button previews a photo in a [CaptionSheet], then sends it with
/// the caption and simulated upload progress.
class ChatAttachmentsExample extends StatefulWidget {
  /// Creates a [ChatAttachmentsExample].
  const ChatAttachmentsExample({super.key});

  @override
  State<ChatAttachmentsExample> createState() => _ChatAttachmentsExampleState();
}

class _ChatAttachmentsExampleState extends State<ChatAttachmentsExample> {
  static const _meId = 'me';
  static const _themId = 'them';

  static const _me = User(id: _meId, name: 'You');
  static const _them = User(id: _themId, name: 'Alex');

  late final InMemoryChatController _chatController;

  // Shared by every voice note, so one plays at a time and keeps playing when
  // its bubble scrolls out of view.
  final _audio = AudioMessageController();

  // Photos the attachment button sends, in turn.
  static const _photosToSend = [1036, 1043, 1039];
  int _sentPhotos = 0;
  Timer? _upload;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Oldest first: index 0 is at the top, the last message at the bottom.
    _chatController = InMemoryChatController(
      messages: [
        Message.text(
          id: 'msg-1',
          authorId: _themId,
          text: 'Here are my pics from my vacation!',
          createdAt: now.subtract(const Duration(minutes: 9)),
        ),
        _photo('msg-2', 1018, 'Day one in the mountains', now, minutesAgo: 8),
        _photo('msg-3', 1015, 'River hike', now, minutesAgo: 8),
        _photo(
          'msg-4',
          593,
          'Met this guy at the wildlife sanctuary',
          now,
          minutesAgo: 7,
          isPortrait: true,
        ),
        Message.file(
          id: 'msg-5',
          authorId: _themId,
          source:
              'https://raw.githubusercontent.com/py-pdf/sample-files/main/009-pdflatex-geotopo/GeoTopo.pdf',
          name: 'GeoTopo.pdf',
          size: 5321132,
          mimeType: 'application/pdf',
          createdAt: now.subtract(const Duration(minutes: 6)),
        ),
        Message.text(
          id: 'msg-6',
          authorId: _meId,
          text:
              'Amazing! Here is a clip from my trip, and the rest of my photos.',
          createdAt: now.subtract(const Duration(minutes: 4)),
        ),
        Message.video(
          id: 'msg-7',
          authorId: _meId,
          source:
              'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
          name: 'butterfly.mp4',
          text: 'A butterfly in the garden',
          width: 1280,
          height: 720,
          metadata: const {ChatAttachmentMetadata.durationMs: 8000},
          createdAt: now.subtract(const Duration(minutes: 3)),
        ),
        Message.file(
          id: 'msg-8',
          authorId: _meId,
          source: 'https://example.com/vacation-photos.zip',
          name: 'vacation-photos.zip',
          size: 24117248,
          createdAt: now.subtract(const Duration(minutes: 2)),
        ),
        Message.audio(
          id: 'msg-8b',
          authorId: _themId,
          source:
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          duration: const Duration(minutes: 6, seconds: 12),
          text: 'The song from the road trip',
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
        _photo(
          'msg-9',
          1016,
          'Road trip sunset',
          now,
          minutesAgo: 1,
          authorId: _meId,
        ),
      ],
    );
  }

  // A picsum photo with a 400px thumbnail of the same shape in its metadata.
  static ImageMessage _photo(
    String id,
    int picsumId,
    String? caption,
    DateTime now, {
    required int minutesAgo,
    String authorId = _themId,
    bool isPortrait = false,
    MessageStatus? status,
  }) {
    final (width, height) = isPortrait ? (1200, 1600) : (1600, 1200);
    return Message.image(
          id: id,
          authorId: authorId,
          source: 'https://picsum.photos/id/$picsumId/$width/$height',
          text: caption,
          width: width.toDouble(),
          height: height.toDouble(),
          status: status,
          metadata: {
            ChatAttachmentMetadata.thumbnail:
                'https://picsum.photos/id/$picsumId/${width ~/ 4}/${height ~/ 4}',
          },
          createdAt: now.subtract(Duration(minutes: minutesAgo)),
        )
        as ImageMessage;
  }

  // Sends the next photo the way an app would: preview it with a caption
  // field, show it at once as sending, report the upload's progress, then
  // mark it sent. A real app would pick the photo with image_picker, and its
  // upload would also swap in the stored file's URL, keeping the message id.
  Future<void> _sendPhoto() async {
    if (_upload?.isActive ?? false) return;
    final picsumId = _photosToSend[_sentPhotos % _photosToSend.length];
    final caption = await CaptionSheet.show(
      context,
      NetworkImage('https://picsum.photos/id/$picsumId/400/300'),
    );
    if (caption == null || !mounted) return;
    _sentPhotos++;
    final sending = _photo(
      'sent-${DateTime.now().microsecondsSinceEpoch}',
      picsumId,
      // The caption is the image message's text.
      caption.isEmpty ? null : caption,
      DateTime.now(),
      minutesAgo: 0,
      authorId: _meId,
      status: MessageStatus.sending,
    );
    await _chatController.insertMessage(sending);
    var progress = 0.0;
    _upload = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      progress += 0.05;
      _chatController.updateUploadProgress(sending.id, progress);
      if (progress < 1) return;
      timer.cancel();
      unawaited(
        _chatController.updateMessage(
          sending,
          sending.copyWith(status: MessageStatus.sent, sentAt: DateTime.now()),
        ),
      );
    });
  }

  @override
  void dispose() {
    _upload?.cancel();
    _chatController.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<User?> _resolveUser(String id) async => id == _meId ? _me : _them;

  // Share, Download and opening other files are callbacks, so a real app
  // would hand them to share_plus, a file saver or url_launcher. The app's
  // ScaffoldMessenger shows the snack bar over whichever viewer is open.
  void _showSnack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _describe(Message message) => switch (message) {
    final FileMessage file => file.name,
    final VideoMessage video => video.name ?? 'video',
    _ => 'image',
  };

  @override
  Widget build(BuildContext context) {
    final attachments = ChatAttachments(
      audioController: _audio,
      // The poster is bundled with the example, so it comes from a callback
      // instead of the message's metadata.
      videoThumbnail: (message) =>
          const AssetImage('assets/images/video-butterfly.jpg'),
      onShare: (message, origin) => _showSnack('Share ${_describe(message)}'),
      onDownload: (message) => _showSnack('Download ${_describe(message)}'),
      onOpenFile: (message) => _showSnack('Open ${_describe(message)}'),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Attachments'),
        actions: const [BrightnessButton()],
      ),
      body: Chat(
        currentUserId: _meId,
        resolveUser: _resolveUser,
        chatController: _chatController,
        theme: ChatTheme.fromThemeData(Theme.of(context)),
        builders: attachments.apply(),
        onAttachmentTap: () => unawaited(_sendPhoto()),
        onMessageSend: (text) => unawaited(
          _chatController.insertMessage(
            Message.text(
              id: '${DateTime.now().microsecondsSinceEpoch}',
              authorId: _meId,
              text: text,
              createdAt: DateTime.now(),
            ),
          ),
        ),
      ),
    );
  }
}
