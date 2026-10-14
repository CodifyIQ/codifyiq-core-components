# codifyiq_chat_attachments example

```dart
import 'package:codifyiq_chat_attachments/codifyiq_chat_attachments.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:material_ui/material_ui.dart';

Widget buildChat(ChatController controller) {
  final attachments = ChatAttachments(
    onShare: (message, origin) => debugPrint('Share ${message.id}'),
    onDownload: (message) => debugPrint('Download ${message.id}'),
  );
  return Chat(
    chatController: controller,
    currentUserId: 'me',
    resolveUser: (id) async => User(id: id),
    builders: attachments.apply(),
  );
}
```

A runnable catalog demonstrating every CodifyIQ component lives in the
[`example/` app at the repository root](https://github.com/CodifyIQ/codifyiq-core-components/tree/dev/example).
