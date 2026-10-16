import 'package:codifyiq_chat_attachments/src/attachment_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a URL that Uri rejects is still a URL, escaped', () {
    final source = AttachmentSource.parse('https://example.com/100%off.pdf');

    expect(source, isA<RemoteAttachmentSource>());
    expect(
      (source as RemoteAttachmentSource).uri.toString(),
      'https://example.com/100%25off.pdf',
    );
  });
}
