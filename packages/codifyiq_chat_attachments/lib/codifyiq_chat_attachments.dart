/// Image, file, video and audio message bubbles for `flutter_chat_ui` that
/// open the CodifyIQ image, PDF and video viewers and play audio.
library;

// Needed to share audio playback across a chat and to build an audio bubble,
// so apps don't have to depend on codifyiq_audio_message themselves.
export 'package:codifyiq_audio_message/codifyiq_audio_message.dart'
    show AudioMessageController, AudioMessageSource;

export 'src/chat_attachment_action.dart';
export 'src/chat_attachment_labels.dart';
export 'src/chat_attachment_metadata.dart';
export 'src/chat_attachments.dart';
export 'src/chat_audio_attachment.dart';
export 'src/chat_file_attachment.dart';
export 'src/chat_image_attachment.dart';
export 'src/chat_video_attachment.dart';
